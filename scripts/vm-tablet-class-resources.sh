#!/usr/bin/env bash
# Pin a libvirt guest to tablet-class resources for field-like smoke
# (RCA / fleet: ~2 GiB RAM, few slow cores). Required for DrakeVox TTS
# latency QA — sls-camera#13 — so a fat host VM does not hide stalls.
#
# Usage:
#   ./scripts/vm-tablet-class-resources.sh [domain]
#   VCPUS=1 ./scripts/vm-tablet-class-resources.sh   # optional stress profile
#
# Default: 2 vCPU, 2048 MiB. Domain must be shut off for vCPU/maxmem changes.
set -euo pipefail

URI="${LIBVIRT_URI:-qemu:///system}"
DOM="${1:-sls-appliance-phase1}"
# 2 GiB in KiB (libvirt setmem units)
MEM_KIB="${MEM_KIB:-2097152}"
VCPUS="${VCPUS:-2}"

if ! command -v virsh >/dev/null 2>&1; then
  echo "virsh not found" >&2
  exit 1
fi

echo "URI=$URI domain=$DOM  target: ${VCPUS} vCPU / $((MEM_KIB / 1024)) MiB"

state=$(virsh -c "$URI" domstate "$DOM" 2>/dev/null || true)
if [[ -z "$state" ]]; then
  echo "ERROR: domain not found: $DOM" >&2
  exit 1
fi
echo "current state: $state"
virsh -c "$URI" dominfo "$DOM" | grep -E 'CPU\(s\)|Max memory|Used memory' || true

if [[ "$state" != "shut off" ]]; then
  echo "Shutting down $DOM (required for resource pin)…"
  virsh -c "$URI" shutdown "$DOM" || true
  for _ in $(seq 1 60); do
    state=$(virsh -c "$URI" domstate "$DOM" 2>/dev/null || echo unknown)
    [[ "$state" == "shut off" ]] && break
    sleep 1
  done
  state=$(virsh -c "$URI" domstate "$DOM")
  if [[ "$state" != "shut off" ]]; then
    echo "WARN: still '$state' — trying destroy (force off)"
    virsh -c "$URI" destroy "$DOM" || true
    sleep 1
  fi
fi

echo "Applying --config: memory=${MEM_KIB} KiB vcpus=${VCPUS}"
virsh -c "$URI" setmaxmem "$DOM" "$MEM_KIB" --config
virsh -c "$URI" setmem "$DOM" "$MEM_KIB" --config
# maximum first, then current
virsh -c "$URI" setvcpus "$DOM" "$VCPUS" --config --maximum 2>/dev/null \
  || virsh -c "$URI" setvcpus "$DOM" "$VCPUS" --config --maximum --live 2>/dev/null \
  || true
virsh -c "$URI" setvcpus "$DOM" "$VCPUS" --config

echo "Starting $DOM…"
virsh -c "$URI" start "$DOM"
sleep 2
echo "After start:"
virsh -c "$URI" dominfo "$DOM" | grep -E 'CPU\(s\)|Max memory|Used memory|State' || true
echo "OK — use for TTS/app smoke under tablet-class limits (sls-camera#13)."
echo "Guest check: free -h && nproc"
