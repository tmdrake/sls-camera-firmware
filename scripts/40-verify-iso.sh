#!/usr/bin/env bash
# Placeholder: verify ISO checksum / boot files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "No ISO verifier yet. Place builds in $ROOT/out/ and re-run after Phase 2."
ls -la "$ROOT/out" 2>/dev/null || true
