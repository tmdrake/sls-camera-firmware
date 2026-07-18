#!/usr/bin/env bash
# Phase 2 stub: produce a tablet ISO (not fully implemented yet).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

cat <<'EOF'
=== SLS Camera Firmware — ISO build (Phase 2) ===

This script is a placeholder. Phase 1 is install-appliance.sh on a base OS.

Planned options (pick one in docs/ARCHITECTURE.md when ready):

  1) live-build  — scriptable Debian/Ubuntu live + installer
  2) Cubic      — GUI remaster of Lubuntu ISO
  3) mkosi       — declarative image builds

Prerequisites before implementing:
  - vendor/ populated (./scripts/10-fetch-offline.sh)
  - app synced (./scripts/20-sync-app.sh)
  - install-appliance.sh proven on a tablet or VM

When implemented, output will land in:  out/sls-camera-firmware-*.iso

EOF

mkdir -p "$ROOT/out"
echo "Stub only — no ISO produced."
exit 0
