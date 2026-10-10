#!/usr/bin/env bash
# wai -- installer. Symlinks the launcher into PATH (never copies).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
chmod +x "${REPO}/wai"
ln -sfn "${REPO}/wai" "${BIN}/wai"
echo "wai -> ${BIN}/wai"
