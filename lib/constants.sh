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

# Cross-invocation state (mon on then mon off, or cmd_* after mon on).
# WAI_STATE_FILE carries the iwd state and interface so a later process
# can restore the system.
readonly WAI_STATE_FILE="${TMPDIR:-/tmp}/wai.state"

# Per-process temp directory. Cleaned by cleanup().
readonly TMP=$(mktemp -d "${TMPDIR:-/tmp}/wai.XXXXXX")

# _sys: run a command unless WAI_DRY_RUN=1, in which case print it.
_sys() {
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] $*"
        return 0
    fi
    "$@"
}

# _sys_bg: background version. Echoes the PID to stdout; in dry-run it
# echoes 0 so callers can still use it as a placeholder.
_sys_bg() {
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] $* (background)"
        echo 0
        return 0
    fi
    "$@" &
    echo $!
}
