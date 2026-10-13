#!/usr/bin/env bash
# lib/constants.sh -- Global constants for wai.
# Not executed directly. Loaded by the entrypoint.

readonly VER="6.0"

readonly SCAN_SEC=20
readonly SCAN_CLIENT_SEC=12
readonly CAP_MAX_SEC=90
readonly DEAUTH_N=8
readonly DEAUTH_ROUNDS=2
readonly DEAUTH_INTERVAL=3
readonly META_MAX_AGE=1800
# Metadata cache directory. Follows the XDG Base Directory spec so
# nothing lands in $HOME directly. LEGACY_META_DIR is the previous
# location kept for a one-time migration in init_meta().
readonly META_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wai"
readonly LEGACY_META_DIR="${HOME}/wssids"
readonly MAX_TRIES_DEFAULT=3

HAS_HCXPCAPNGTOOL=""
HAS_CAP2HCCAPX=""
HAS_TSHARK=""

# Dry-run: when 1, state-changing actions are printed instead of executed.
# Enabled by --dry-run / -n or by exporting WAI_DRY_RUN=1. Lets the whole
# flow be exercised on a non-root host (Termux) without touching the
# network stack.
WAI_DRY_RUN="${WAI_DRY_RUN:-0}"

# Per-process temp directory. Cleaned by cleanup() for subcommands that
# call install_trap(). For invocations that never reach install_trap
# (usage, -V, -h) the trap below covers it, so no temp dir is orphaned.
TMP=$(mktemp -d "${TMPDIR:-/tmp}/wai.XXXXXX")
readonly TMP
trap 'rm -rf "$TMP"' EXIT
