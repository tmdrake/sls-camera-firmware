#!/usr/bin/env bash
# Phase 2 entry: ISO / field media.
# Stage A (available now): field USB via 50-build-field-usb.sh
# Stage B (later): single remastered Lubuntu appliance ISO
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-help}"

usage() {
  cat <<'EOF'
=== SLS Camera Firmware — Phase 2 media ===

Stage A — Field USB (recommended now)
  Requires: 10-fetch-offline.sh + 20-sync-app.sh
  Stick:    FAT32 (prep with prep-sls-media-usb.sh)

    sudo ./scripts/50-build-field-usb.sh /dev/sdX1
    sudo ISO=/path/to/lubuntu-26.04-desktop-amd64.iso \
         ./scripts/50-build-field-usb.sh /dev/sdX1

Stage B — Single appliance ISO (not automated yet)
  Tooling candidates: Cubic | live-build | mkosi
  See docs/ISO-AND-FIELD-USB.md

Other:
    ./scripts/30-build-iso.sh status   # vendor + app readiness
    ./scripts/30-build-iso.sh help

Output directories:
    out/           future ISO files
    (USB mount)    Stage A payload
EOF
}

status() {
  echo "=== Readiness ==="
  local ndebs nwheels
  ndebs=$(find vendor/debs -name '*.deb' 2>/dev/null | wc -l)
  nwheels=$(find vendor/wheels -type f 2>/dev/null | wc -l)
  echo "  vendor/debs:    $ndebs"
  echo "  vendor/wheels:  $nwheels"
  echo "  pose model:     $( [[ -s vendor/models/pose_landmarker_lite.task ]] && echo OK || echo MISSING )"
  echo "  app run.sh:     $( [[ -x build/app/software/linux/viewer/run.sh ]] && echo OK || echo MISSING )"
  echo "  app-ref:        $(grep -v '^#' packages/app-ref.txt | head -1)"
  echo "  install-appliance.sh: $( [[ -x scripts/install-appliance.sh ]] && echo OK || echo MISSING )"
  echo
  if [[ "$ndebs" -lt 50 ]]; then
    echo "  WARN: few debs — run ./scripts/10-fetch-offline.sh (FETCH_DEPS=1)"
  fi
  if [[ ! -x build/app/software/linux/viewer/run.sh ]]; then
    echo "  WARN: run ./scripts/20-sync-app.sh"
  fi
  mkdir -p out
  ls -la out 2>/dev/null || true
}

case "$MODE" in
  help|-h|--help|"") usage ;;
  status) status ;;
  usb|field-usb)
    shift || true
    exec "$ROOT/scripts/50-build-field-usb.sh" "$@"
    ;;
  iso|stage-b)
    cat <<'EOF'
Stage B single-ISO build is not implemented yet.

Work plan:
  1) Ship Stage A field USB (50-build-field-usb.sh) to a real tablet
  2) Choose Cubic vs live-build vs mkosi (docs/ISO-AND-FIELD-USB.md)
  3) Implement remaster that embeds vendor/ + install-appliance or preinstalls /opt/sls-camera

EOF
    status
    exit 1
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac
