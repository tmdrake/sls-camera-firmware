#!/usr/bin/env bash
# Apply SST-vs-SOF audio experiment on a live appliance (lab RCA).
# Usage (on tablet as root, or via ssh):
#   sudo ./scripts/apply-audio-sst-on-target.sh
#   sudo ./scripts/apply-audio-sst-on-target.sh --reboot
set -euo pipefail

REBOOT=0
[[ "${1:-}" == "--reboot" ]] && REBOOT=1

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

CONF_SRC="$(cd "$(dirname "$0")/.." && pwd)/overlay/etc/modprobe.d/sls-audio-sst.conf"
DEST=/etc/modprobe.d/sls-audio-sst.conf

if [[ -f "$CONF_SRC" ]]; then
  install -D -m 644 "$CONF_SRC" "$DEST"
else
  # Inline if run without full tree
  cat >"$DEST" <<'EOF'
# Force Intel SST (not SOF) — see firmware docs/devices/rca-w101as23t2.md
options snd-intel-dspcfg dsp_driver=2
blacklist snd_sof_acpi_intel_byt
EOF
  chmod 644 "$DEST"
fi

echo "Installed $DEST"
echo "---"
cat "$DEST"
echo "---"
modinfo snd_intel_dspcfg 2>/dev/null | grep -A3 parm || true
echo "Module options take effect after module reload or reboot."
# initramfs so early DSP pick uses the option
if command -v update-initramfs >/dev/null; then
  update-initramfs -u || true
  echo "update-initramfs done"
fi

if [[ "$REBOOT" == "1" ]]; then
  echo "Rebooting in 3s…"
  sleep 3
  systemctl reboot
else
  echo "Reboot required: sudo reboot"
  echo "After boot check:"
  echo "  cat /proc/asound/cards"
  echo "  dmesg | grep -iE 'sof|sst|rt5651|bytcr'"
  echo "  wpctl status | sed -n '/Sinks/,/Sources/p'"
fi
