#!/usr/bin/env bash
# Verify Stage A field USB payload and/or Stage B out/ ISO directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOUNT="${MOUNT:-}"
ERR=0

ok() { echo "  OK  $*"; }
bad() { echo "  FAIL $*"; ERR=1; }

echo "=== Verify field media / ISO readiness ==="

# Host tree
echo "-- host repo --"
ndebs=$(find "$ROOT/vendor/debs" -name '*.deb' 2>/dev/null | wc -l)
nwheels=$(find "$ROOT/vendor/wheels" -type f 2>/dev/null | wc -l)
[[ "$ndebs" -ge 50 ]] && ok "vendor/debs ($ndebs)" || bad "vendor/debs ($ndebs) — run 10-fetch-offline.sh"
[[ "$nwheels" -ge 10 ]] && ok "vendor/wheels ($nwheels)" || bad "vendor/wheels ($nwheels)"
[[ -s "$ROOT/vendor/models/pose_landmarker_lite.task" ]] && ok "pose model" || bad "pose model"
[[ -f "$ROOT/build/app/software/linux/viewer/run.sh" ]] && ok "build/app viewer" || bad "build/app — run 20-sync-app.sh"
[[ -x "$ROOT/scripts/install-appliance.sh" ]] && ok "install-appliance.sh" || bad "install-appliance.sh"
echo "  app-ref: $(grep -v '^#' "$ROOT/packages/app-ref.txt" | head -1)"

# Optional USB mount
if [[ -z "$MOUNT" ]]; then
  for c in /media/*/SLS-MEDIA /run/media/*/SLS-MEDIA /mnt/sls-field-usb /mnt/sls-media; do
    if [[ -d "$c/firmware" || -f "$c/install-from-usb.sh" ]]; then
      MOUNT="$c"
      break
    fi
  done
fi

if [[ -n "$MOUNT" && -d "$MOUNT" ]]; then
  echo "-- field USB: $MOUNT --"
  [[ -f "$MOUNT/install-from-usb.sh" ]] && ok "install-from-usb.sh" || bad "install-from-usb.sh"
  [[ -f "$MOUNT/BOOTSTRAP.md" ]] && ok "BOOTSTRAP.md" || bad "BOOTSTRAP.md"
  [[ -f "$MOUNT/firmware/scripts/install-appliance.sh" ]] && ok "firmware/scripts/install-appliance.sh" || bad "firmware tree"
  [[ -f "$MOUNT/firmware/build/app/software/linux/viewer/run.sh" ]] && ok "firmware app run.sh" || bad "firmware app"
  mdebs=$(find "$MOUNT/firmware/vendor/debs" -name '*.deb' 2>/dev/null | wc -l)
  [[ "$mdebs" -ge 50 ]] && ok "firmware vendor/debs ($mdebs)" || bad "firmware vendor/debs ($mdebs)"
  [[ -d "$MOUNT/sls-captures" ]] && ok "sls-captures/" || bad "sls-captures/"
  du -sh "$MOUNT/firmware" 2>/dev/null | awk '{print "  size firmware: "$1}'
else
  echo "-- field USB: (not mounted; set MOUNT=/path/to/SLS-MEDIA) --"
fi

echo "-- out/ (Stage B ISO) --"
mkdir -p "$ROOT/out"
shopt -s nullglob
isos=("$ROOT"/out/*.iso)
if [[ ${#isos[@]} -gt 0 ]]; then
  ls -lh "${isos[@]}"
  ok "ISO file(s) present"
else
  echo "  (no ISO yet — Stage B not built)"
fi

echo
if [[ "$ERR" -eq 0 ]]; then
  echo "All checks passed."
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
