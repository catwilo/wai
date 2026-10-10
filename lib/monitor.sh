#!/usr/bin/env bash
# lib/monitor.sh -- Monitor mode on/off.
# Not executed directly. Loaded by the entrypoint.
#
# monitor_up:   put IFACE in monitor mode, set MON to the created iface.
# monitor_down: take MON out of monitor mode.
#
# These are the only two entry points into monitor-mode control. Every
# subcommand that needs monitor mode calls monitor_up; `wai mon off` and
# cleanup() call monitor_down. No other module manipulates MON directly.
#
# Every side effect is guarded by WAI_DRY_RUN: under dry-run the function
# prints what it would do and returns without touching the system.

monitor_up() {
    hdr "Monitor Mode"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] would kill dhcpcd, wpa_supplicant"
        dbg "[dry-run] airmon-ng check kill"
        info "Enabling monitor mode on '${IFACE}'..."
        dbg "[dry-run] airmon-ng start ${IFACE}"
        MON="${IFACE}mon"
        ok "Monitor interface (dry-run): ${MON}"
        return 0
    fi

    info "Killing interfering processes (dhcpcd, wpa_supplicant)..."
    pkill -x dhcpcd         2>/dev/null \
        && dbg "dhcpcd terminated."         || dbg "dhcpcd not running."
    pkill -x wpa_supplicant 2>/dev/null \
        && dbg "wpa_supplicant terminated." || dbg "wpa_supplicant not running."
    sleep 1

    info "airmon-ng check kill (auto-answer to prompts)..."
    echo "y" | airmon-ng check kill 2>&1 \
        | while IFS= read -r l; do dbg "  $l"; done || true
    sleep 1

    pkill -9 iwd    2>/dev/null || true
    pkill -9 dhcpcd 2>/dev/null || true
    sleep 1

    info "Enabling monitor mode on '${IFACE}'..."
    local airmon_out
    airmon_out=$(echo "y" | airmon-ng start "$IFACE" 2>&1) || true
    echo "$airmon_out" | while IFS= read -r l; do dbg "  airmon: $l"; done

    MON=$(echo "$airmon_out" \
        | sed -n 's/.*\]\(wlan[0-9]*mon\).*/\1/p' \
        | head -1)

    if [[ -z "$MON" ]]; then
        MON=$(iw dev 2>/dev/null \
            | awk '/Interface/{i=$2} /type monitor/{print i}' \
            | head -1)
        [[ -n "$MON" ]] \
            && dbg "Monitor interface from fallback (iw dev): '${MON}'" \
            || die "No monitor interface created.\n  Check: sudo iw dev\n  airmon-ng output:\n${airmon_out}"
    else
        dbg "Monitor interface from airmon output: '${MON}'"
    fi

    ip link set "$MON" up 2>/dev/null \
        && dbg "${MON} set up with 'ip link set up'." || true
    sleep 1

    dbg "Final state of ${MON}:"
    iw dev "$MON" info 2>/dev/null \
        | while IFS= read -r l; do dbg "  $l"; done || true

    ok "Monitor interface active: ${MON}"
}

monitor_down() {
    hdr "Disabling monitor mode"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] would pkill airodump-ng, aireplay-ng"
        dbg "[dry-run] airmon-ng stop ${MON:-${IFACE}mon}"
        MON=""
        return 0
    fi

    pkill -9 -f "airodump-ng|aireplay-ng" 2>/dev/null || true
    sleep 1

    local candidate="${MON}"
    if [[ -z "$candidate" ]]; then
        candidate=$(iw dev 2>/dev/null \
            | awk '/Interface/{i=$2} /type monitor/{print i}' \
            | head -1)
        if [[ -z "$candidate" ]]; then
            candidate="${IFACE}mon"
        fi
    fi

    airmon-ng stop "$candidate" 2>&1 \
        | while IFS= read -r l; do dbg "  $l"; done || true
    MON=""
    ok "Monitor mode disabled."
}
