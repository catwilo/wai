#!/usr/bin/env bash
# lib/iwd.sh -- iwd daemon control (stop before capture, restore after).
# Not executed directly. Loaded by the entrypoint.
#
# State handoff: when iwd is stopped, IWD_WAS_UP and IWD_NET are written
# to WAI_STATE_FILE so a later process can restore iwd without relying on
# in-process state.

_save_iwd_state() {
    local dir
    dir="$(dirname "$WAI_STATE_FILE")"
    mkdir -p "$dir" 2>/dev/null || true
    {
        printf "IWD_STATE_WAS_UP=%s\n" "$IWD_WAS_UP"
        printf "IWD_STATE_NET=%s\n" "$IWD_NET"
        printf "IWD_STATE_IFACE=%s\n" "$IFACE"
    } >"$WAI_STATE_FILE"
    chmod 600 "$WAI_STATE_FILE" 2>/dev/null || true
}

save_and_stop_iwd() {
    hdr "iwd management"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] skipping iwd stop"
        return 0
    fi

    if ! systemctl is-active --quiet iwd 2>/dev/null; then
        warn "iwd not active -- nothing to stop."
        return 0
    fi

    IWD_WAS_UP=1

    IWD_NET=$(iwctl station "$IFACE" show 2>/dev/null |
        awk '/Connected network/ {print $NF}' |
        tr -d '[:space:]') || true

    if [[ -n "$IWD_NET" ]]; then
        ok "Network saved for restore: '${IWD_NET}'"
    else
        warn "iwd active but no network currently connected."
    fi

    systemctl stop iwd 2>&1 |
        while IFS= read -r l; do dbg "  stop: $l"; done || true
    systemctl mask iwd 2>&1 |
        while IFS= read -r l; do dbg "  mask: $l"; done || true

    pkill -9 iwd 2>/dev/null || true
    pkill -9 dhcpcd 2>/dev/null || true
    sleep 2

    _save_iwd_state
    ok "iwd stopped and masked."
}
