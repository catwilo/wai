#!/usr/bin/env bash
# lib/cleanup.sh -- Resource cleanup and system restore.
# Not executed directly. Loaded by the entrypoint.
#
# cleanup() is the single exit handler, registered by install_trap AFTER
# the subcommand's preflight. Invocations that never touch the system
# (usage, -h, -V) do not install it and print no noise on exit.

cleanup() {
    local rc=$?
    echo "" >&2
    warn "Cleaning up..."

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] cleanup: nothing to do"
        rm -f "$WAI_STATE_FILE" 2>/dev/null || true
        rm -rf "$TMP"
        if [[ $rc -eq 0 ]]; then
            ok "Finished OK (rc=0)."
        else
            warn "Finished with errors (rc=${rc})."
        fi
        return
    fi

    pkill -9 -f "airodump-ng|aireplay-ng" 2>/dev/null || true
    sleep 1

    if [[ -n "$MON" ]]; then
        dbg "Stopping monitor: $MON"
        airmon-ng stop "$MON" 2>&1 |
            while IFS= read -r l; do dbg "  $l"; done || true
    fi

    # Cross-process iwd state: if this process did not stop iwd itself,
    # read the state written by a previous invocation (mon on).
    local iwd_up="$IWD_WAS_UP"
    local iwd_net="$IWD_NET"
    if [[ "$iwd_up" -eq 0 && -f "$WAI_STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$WAI_STATE_FILE" 2>/dev/null || true
        iwd_up="${IWD_STATE_WAS_UP:-0}"
        iwd_net="${IWD_STATE_NET:-}"
    fi

    if [[ "$iwd_up" -eq 1 ]]; then
        info "Restoring iwd..."
        systemctl unmask iwd 2>/dev/null || true
        systemctl enable iwd 2>/dev/null || true
        systemctl start iwd 2>/dev/null || true
        sleep 3

        if [[ -n "$iwd_net" ]]; then
            info "Reconnecting to '${iwd_net}'..."
            local w=0
            until iwctl station "$IFACE" show &>/dev/null || ((w >= 15)); do
                printf "\r  Waiting for iwd... %ds" "$w" >&2
                sleep 1
                w=$((w + 1))
            done
            echo "" >&2
            iwctl station "$IFACE" connect "$iwd_net" 2>/dev/null || true
            sleep 5

            if iwctl station "$IFACE" show 2>/dev/null | grep -qi "connected"; then
                ok "Reconnected to '${iwd_net}'."
            else
                warn "Reconnect failed. Run manually:"
                warn "  sudo iwctl station ${IFACE} connect '${iwd_net}'"
            fi
        fi
    fi

    rm -f "$WAI_STATE_FILE" 2>/dev/null || true
    rm -rf "$TMP"
    if [[ $rc -eq 0 ]]; then
        ok "Finished OK (rc=0)."
    else
        warn "Finished with errors (rc=${rc})."
    fi
}

install_trap() {
    trap cleanup EXIT
    trap 'warn "INT/TERM received."; exit 130' INT TERM
}
