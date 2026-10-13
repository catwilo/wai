#!/usr/bin/env bash
# wai -- installer. Symlinks the launcher into PATH (never copies).
# Honors $PREFIX/bin on Termux, falls back to ~/.local/bin elsewhere.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX}/bin" ]; then
    BIN="${PREFIX}/bin"
else
    BIN="${HOME}/.local/bin"
fi

mkdir -p "$BIN"
chmod +x "${REPO}/wai"
ln -sfn "${REPO}/wai" "${BIN}/wai"
echo "wai -> ${BIN}/wai"

"${BIN}/wai" -V
