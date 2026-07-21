#!/usr/bin/env bash
# Best-effort Goodix rebind after failed I2C probe (Cherry Trail).
# Often fails until cold power cycle — see docs/TOUCH-GOODIX.md
set -u
if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi
echo "sls-touch-rebind: attempting Goodix rebind…"
echo GDIX1002:00 >/sys/bus/i2c/drivers/Goodix-TS/unbind 2>/dev/null || true
sleep 1
modprobe -r goodix_ts 2>/dev/null || true
sleep 1
modprobe goodix_ts 2>/dev/null || modprobe goodix 2>/dev/null || true
sleep 2
if dmesg | tail -30 | grep -qi 'Goodix.*failed\|I2C communication failure'; then
  echo "sls-touch-rebind: still failing I2C — cold power cycle recommended"
  dmesg | tail -15 | grep -i goodix || true
  exit 1
fi
echo "sls-touch-rebind: no recent failure lines (check xinput as user)"
exit 0
