#!/usr/bin/env bash
# DANGEROUS: write an image to a block device.
# Refuses to run unless I_UNDERSTAND=1 and DEVICE=/dev/sdX are set.
set -euo pipefail

if [[ "${I_UNDERSTAND:-}" != "1" ]]; then
  cat <<'EOF' >&2
Refusing to run.

This script will overwrite a block device. When Phase 2 ISOs exist:

  I_UNDERSTAND=1 DEVICE=/dev/sdX IMAGE=out/sls-camera-firmware.iso \\
    ./scripts/install-to-device.sh

Double-check DEVICE with lsblk. Wrong device destroys data.
EOF
  exit 1
fi

if [[ -z "${DEVICE:-}" || -z "${IMAGE:-}" ]]; then
  echo "Set DEVICE=/dev/… and IMAGE=path/to.iso" >&2
  exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
  echo "Not a block device: $DEVICE" >&2
  exit 1
fi

if [[ ! -f "$IMAGE" ]]; then
  echo "Image not found: $IMAGE" >&2
  exit 1
fi

echo "About to write $IMAGE → $DEVICE"
echo "Press Ctrl-C within 5s to abort…"
sleep 5
dd if="$IMAGE" of="$DEVICE" bs=4M status=progress conv=fsync
sync
echo "Done."
