#!/usr/bin/env bash
# Attach / detach Xbox 360 Kinect USB devices to a libvirt guest (KVM).
#
# Usage (on the *host*):
#   ./scripts/vm-kinect-usb.sh status
#   ./scripts/vm-kinect-usb.sh attach
#   ./scripts/vm-kinect-usb.sh detach
#   ./scripts/vm-kinect-usb.sh reattach    # detach, wait, attach (fixes most glitches)
#   ./scripts/vm-kinect-usb.sh test        # reattach + freenect-camtest in guest if SSH works
#
# Env overrides:
#   VM_NAME=sls-appliance-phase1
#   VIRSH_URI=qemu:///system
#   GUEST_SSH=sls@192.168.122.100     # for "test" / guest lsusb
#   SSHPASS=... or use ssh keys
#
# Kinect NUI IDs: motor 02b0, camera 02ae, audio 02bb (vendor 045e)
set -euo pipefail

VM_NAME="${VM_NAME:-sls-appliance-phase1}"
VIRSH_URI="${VIRSH_URI:-qemu:///system}"
GUEST_SSH="${GUEST_SSH:-sls@192.168.122.100}"
VENDOR="045e"
# order: motor, camera, audio
PRODUCTS=(02b0 02ae 02bb)
NAMES=(motor camera audio)

TMPDIR="${TMPDIR:-/tmp}/sls-kinect-usb-$$"
mkdir -p "$TMPDIR"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

virsh_c() {
  virsh -c "$VIRSH_URI" "$@"
}

xml_for() {
  local id="$1"
  local path="$TMPDIR/k-${id}.xml"
  cat >"$path" <<EOF
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x${VENDOR}'/>
    <product id='0x${id}'/>
  </source>
</hostdev>
EOF
  echo "$path"
}

host_has() {
  lsusb -d "${VENDOR}:$1" >/dev/null 2>&1
}

domain_has_product() {
  local id="$1"
  virsh_c dumpxml "$VM_NAME" 2>/dev/null | grep -q "product id='0x${id}'"
}

domain_state() {
  virsh_c domstate "$VM_NAME" 2>/dev/null || echo "missing"
}

wait_host_kinect() {
  local tries="${1:-15}"
  local i
  for ((i = 1; i <= tries; i++)); do
    local ok=0
    local p
    for p in "${PRODUCTS[@]}"; do
      host_has "$p" && ok=$((ok + 1))
    done
    if [[ "$ok" -eq ${#PRODUCTS[@]} ]]; then
      echo "Host sees all ${#PRODUCTS[@]} Kinect interfaces."
      return 0
    fi
    echo "  waiting for Kinect on host ($ok/${#PRODUCTS[@]})… try $i/$tries"
    sleep 1
  done
  echo "WARN: host still missing some Kinect IDs (power brick on? USB cable?)" >&2
  lsusb | grep -i "$VENDOR" || lsusb | head -5
  return 1
}

# Remove every hostdev for Kinect products from live + config (handles duplicates/stale bus addrs)
strip_kinect_hostdevs() {
  local xml live_xml
  live_xml="$(virsh_c dumpxml "$VM_NAME" 2>/dev/null || true)"
  [[ -z "$live_xml" ]] && return 0

  python3 - "$VM_NAME" "$VIRSH_URI" <<'PY'
import re, subprocess, sys, tempfile, os
name, uri = sys.argv[1], sys.argv[2]
def dump(inactive=False):
    cmd = ["virsh", "-c", uri, "dumpxml", name]
    if inactive:
        cmd.append("--inactive")
    return subprocess.check_output(cmd, text=True)

def strip(xml):
    # drop hostdev blocks that mention 045e / kinect product ids
    def drop(m):
        b = m.group(0)
        if "0x045e" in b or "045e" in b or "0x02b0" in b or "0x02ae" in b or "0x02bb" in b:
            return ""
        return b
    return re.sub(r"<hostdev[\s\S]*?</hostdev>", drop, xml)

# Live detach each matching hostdev
xml = dump(False)
blocks = re.findall(r"<hostdev[\s\S]*?</hostdev>", xml)
for i, block in enumerate(blocks):
    if "0x045e" not in block and "0x02b0" not in block and "0x02ae" not in block and "0x02bb" not in block:
        continue
    path = f"/tmp/sls-detach-{os.getpid()}-{i}.xml"
    open(path, "w").write(block)
    subprocess.run(["virsh", "-c", uri, "detach-device", name, path, "--live"],
                   capture_output=True, text=True)
    try:
        os.remove(path)
    except OSError:
        pass

# Persist: redefine inactive XML without kinect hostdevs
try:
    inactive = dump(True)
except subprocess.CalledProcessError:
    sys.exit(0)
new = strip(inactive)
path = f"/tmp/sls-vm-no-kinect-{os.getpid()}.xml"
open(path, "w").write(new)
subprocess.run(["virsh", "-c", uri, "define", path], check=False)
try:
    os.remove(path)
except OSError:
    pass
PY
}

cmd_status() {
  echo "=== VM ==="
  echo "  name:  $VM_NAME"
  echo "  state: $(domain_state)"
  echo
  echo "=== Host lsusb (045e) ==="
  lsusb | grep -i "$VENDOR" || echo "  (none — unplugged or already passed through)"
  echo
  echo "=== Domain hostdev (Kinect products) ==="
  local p n i
  for i in "${!PRODUCTS[@]}"; do
    p="${PRODUCTS[$i]}"
    n="${NAMES[$i]}"
    if domain_has_product "$p"; then
      echo "  [in VM ] $n  045e:$p"
    elif host_has "$p"; then
      echo "  [on host] $n  045e:$p"
    else
      echo "  [missing] $n  045e:$p"
    fi
  done
}

cmd_detach() {
  echo "Detaching Kinect hostdevs from $VM_NAME…"
  strip_kinect_hostdevs
  sleep 1
  echo "Done. Host should re-enumerate shortly:"
  wait_host_kinect 10 || true
  cmd_status
}

cmd_attach() {
  local st
  st="$(domain_state)"
  if [[ "$st" != "running" ]]; then
    echo "ERROR: domain '$VM_NAME' is not running (state=$st). Start it first:" >&2
    echo "  virsh -c $VIRSH_URI start $VM_NAME" >&2
    exit 1
  fi

  # If already fully attached, report and exit 0
  local all_in=1
  local p
  for p in "${PRODUCTS[@]}"; do
    domain_has_product "$p" || all_in=0
  done
  if [[ "$all_in" -eq 1 ]]; then
    echo "All Kinect products already in domain config/live XML."
    echo "If the guest still cannot open freenect, run: $0 reattach"
    cmd_status
    return 0
  fi

  # Prefer devices on host; if some only in domain, strip and wait
  local need_wait=0
  for p in "${PRODUCTS[@]}"; do
    if ! host_has "$p" && ! domain_has_product "$p"; then
      need_wait=1
    fi
  done
  if [[ "$need_wait" -eq 1 ]] || ! wait_host_kinect 3; then
    echo "Stripping stale hostdevs and waiting for host enumeration…"
    strip_kinect_hostdevs
    wait_host_kinect 20 || true
  fi

  local i id path rc
  for i in "${!PRODUCTS[@]}"; do
    id="${PRODUCTS[$i]}"
    if domain_has_product "$id"; then
      echo "  skip ${NAMES[$i]} (already in domain)"
      continue
    fi
    if ! host_has "$id"; then
      echo "  FAIL ${NAMES[$i]} 045e:$id not on host" >&2
      continue
    fi
    path="$(xml_for "$id")"
    echo "  attach ${NAMES[$i]} 045e:$id …"
    set +e
    virsh_c attach-device "$VM_NAME" "$path" --live --config 2>"$TMPDIR/err-$id.txt"
    rc=$?
    set -e
    if [[ "$rc" -ne 0 ]]; then
      # common: already in config, or in use — try live only, then config only
      if grep -qi "already" "$TMPDIR/err-$id.txt"; then
        echo "    (already configured)"
      elif grep -qi "in use" "$TMPDIR/err-$id.txt"; then
        echo "    in use — trying reattach path for this id…"
        strip_kinect_hostdevs
        sleep 2
        wait_host_kinect 15 || true
        virsh_c attach-device "$VM_NAME" "$path" --live --config \
          || virsh_c attach-device "$VM_NAME" "$path" --live
      else
        cat "$TMPDIR/err-$id.txt" >&2
        # last resort live-only
        virsh_c attach-device "$VM_NAME" "$path" --live || true
      fi
    else
      echo "    OK"
    fi
  done

  sleep 1
  cmd_status
  echo
  echo "In guest:  lsusb | grep 045e"
  echo "           /usr/local/bin/sls-camera"
}

cmd_reattach() {
  echo "=== reattach (clean strip → wait → attach) ==="
  strip_kinect_hostdevs
  sleep 2
  wait_host_kinect 20 || true
  cmd_attach
}

guest_ssh() {
  # Prefer sshpass if SSHPASS set; else plain ssh (keys or agent)
  if [[ -n "${SSHPASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    sshpass -e ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      "$GUEST_SSH" "$@"
  elif [[ -n "${SSHPASS:-}" ]]; then
    # askpass helper
    local ask="$TMPDIR/askpass"
    printf '%s\n' '#!/bin/bash' "echo $(printf %q "$SSHPASS")" >"$ask"
    chmod 700 "$ask"
    DISPLAY= SSH_ASKPASS="$ask" SSH_ASKPASS_REQUIRE=force \
      setsid -w ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      "$GUEST_SSH" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "$GUEST_SSH" "$@"
  fi
}

cmd_test() {
  cmd_reattach
  echo
  echo "=== guest checks (SSH $GUEST_SSH) ==="
  if ! guest_ssh 'echo ok' >/dev/null 2>&1; then
    echo "SSH to $GUEST_SSH failed."
    echo "  Set GUEST_SSH=sls@IP and optionally SSHPASS=20260717"
    echo "  Or run in guest manually: lsusb | grep 045e ; freenect-camtest"
    return 1
  fi
  guest_ssh 'echo "--- lsusb ---"; lsusb | grep -i 045e || lsusb; echo "--- freenect-camtest (8s) ---"; timeout 8 freenect-camtest 2>&1 | tail -15 || true'
  echo
  echo "If depth frames printed, passthrough is good. Start UI: /usr/local/bin/sls-camera"
}

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
}

main() {
  local cmd="${1:-status}"
  case "$cmd" in
    status|st) cmd_status ;;
    attach|a) cmd_attach ;;
    detach|d) cmd_detach ;;
    reattach|re|r) cmd_reattach ;;
    test|t) cmd_test ;;
    -h|--help|help) usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
