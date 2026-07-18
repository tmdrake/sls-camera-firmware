#!/usr/bin/env bash
# Verify build-host prerequisites for offline fetch / appliance packaging.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== SLS firmware host check ==="
echo "Root: $ROOT"
echo "Arch: $(uname -m)"
echo "OS:   $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -a)"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "MISSING: $1"
    return 1
  fi
  echo "OK cmd: $1 ($(command -v "$1"))"
  return 0
}

fail=0
for c in git curl python3; do
  need_cmd "$c" || fail=1
done

if command -v apt-get >/dev/null 2>&1; then
  echo "OK: apt-get present"
else
  echo "WARN: apt-get not found — deb offline fetch will not work on this host"
fi

if [[ -f /home/tmdrake/sls-camera/software/linux/viewer/run.sh ]]; then
  echo "OK: sibling sls-camera checkout detected at ~/sls-camera"
else
  echo "NOTE: no ~/sls-camera — scripts/20-sync-app.sh will clone from APP_URL"
fi

echo "Package list: packages/apt-packages.txt ($(grep -cve '^\s*#' -e '^\s*$' packages/apt-packages.txt || true) packages)"
echo "App pin: $(tr -d '[:space:]' < packages/app-ref.txt | tail -1)"

if [[ "$fail" -ne 0 ]]; then
  echo "Host check FAILED"
  exit 1
fi
echo "Host check OK"
