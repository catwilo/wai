#!/usr/bin/env bash
# lib/state.sh -- Mutable state shared across modules.
# Not executed directly. Loaded by the entrypoint.

IFACE=""
TARGET=""
SSID_NAME=""
CHANNEL=""
OUTDIR="$(pwd)"

MON=""
CAP_FILE=""
IWD_WAS_UP=0
IWD_NET=""

META_FILE=""
META_LOADED=0

# Action for `wai mon` (on|off).
MON_ACTION=""

declare -a TARGETS_RAW=()
declare -a SESSION_RESULTS=()

# _reset_target_state: clears per-target state before the next target.
# Does NOT touch IFACE, MON, OUTDIR, IWD_*, or SESSION_RESULTS.
_reset_target_state() {
    TARGET=""
    SSID_NAME=""
    CHANNEL=""
    CAP_FILE=""
    META_FILE=""
    META_LOADED=0
}
