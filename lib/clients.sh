#!/usr/bin/env bash
# lib/clients.sh -- Detection of clients connected to the target AP.
# Not executed directly. Loaded by the entrypoint.
#
# DISEÑO IMPORTANTE:
# Se usa SIEMPRE un CSV propio (clients-01.csv) con --bssid y --channel fijos.
# NUNCA se reutiliza el CSV del escaneo general (scan-01.csv), porque ese
# scan hops channels and the AP's clients either do not appear or
# aparecen con señal inconsistente.

# Dedicated client CSV (separate from the general network scan)
_CLIENTS_CSV="${TMP}/clients-01.csv"

# _scan_clients_fixed: escaneo corto enfocado al AP con canal y BSSID fijos.
# Elimina el CSV anterior para garantizar datos frescos.
_scan_clients_fixed() {
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] client scan on $MON (channel $CHANNEL)"
        return 0
    fi
    # Borrar CSV previo para forzar datos frescos
    rm -f "${TMP}/clients-01.csv" 2>/dev/null || true

    info "Scanning clients on '${SSID_NAME}' (channel ${CHANNEL}, ${SCAN_CLIENT_SEC}s)..."
    dbg "  airodump-ng --bssid ${TARGET} --channel ${CHANNEL} -> ${TMP}/clients"

    # CRÍTICO: --bssid + --channel fijos evita que airodump salte canales.
    # Without this, the AP's clients appear sporadically or not at all.
    airodump-ng \
        --bssid "$TARGET" \
        --channel "$CHANNEL" \
        --output-format csv \
        --write "${TMP}/clients" \
        "$MON" >"${TMP}/clients_scan.log" 2>&1 &
    local p=$!
    dbg "  airodump-ng clients PID: ${p}"

    local i=0
    while kill -0 "$p" 2>/dev/null && ((i < SCAN_CLIENT_SEC)); do
        printf "\r  ${C}Looking for clients... %2ds${N}" "$((SCAN_CLIENT_SEC - i))" >&2
        sleep 1
        i=$((i + 1))
    done
    printf "\r  %sClient scan complete.             %s\n" "$C" "$N" >&2

    kill "$p" 2>/dev/null || true
    wait "$p" 2>/dev/null || true

    if [[ ! -f "$_CLIENTS_CSV" ]]; then
        warn "No client CSV generated. airodump log:"
        while IFS= read -r l; do warn "  $l"; done <"${TMP}/clients_scan.log" 2>/dev/null || true
    fi
}

# _parse_clients_from_csv: read the CSV and extract clients of TARGET AP.
# $1 = ruta al CSV
# Imprime tabla a stderr, devuelve conteo a stdout.
_parse_clients_from_csv() {
    local csv="$1"
    if [[ ! -f "$csv" ]]; then
        echo "0"
        return 0
    fi

    # Table of detected clients -> stderr
    local table
    table=$(awk -F',' -v ap="${TARGET^^}" '
        /^[[:space:]]*$/ { past=1; next }
        past && /^[0-9A-Fa-f]{2}:/ {
            for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
            if (toupper($6)==ap)
                printf "    MAC=%-20s  AP=%-20s  Signal=%s dBm\n",$1,$6,$4
        }' "$csv" 2>/dev/null) || true

    if [[ -n "$table" ]]; then
        dbg "Clients detected for AP ${TARGET}:"
        echo "$table" >&2
    else
        dbg "No clients in the CSV client section for AP ${TARGET}"
        dbg "  (CSV: ${csv})"
    fi

    # Count -> stdout (the only numeric value)
    awk -F',' -v ap="${TARGET^^}" '
        /^[[:space:]]*$/ { past=1; next }
        past && /^[0-9A-Fa-f]{2}:/ {
            for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
            if (toupper($6)==ap) count++
        }
        END { print count+0 }' "$csv" 2>/dev/null || echo "0"
}

# detect_clients: scan and report clients. Always fresh scan
# con canal fijo para garantizar detección correcta.
# Prints to stdout ONLY the integer client count.
detect_clients() {
    _scan_clients_fixed

    local n
    n=$(_parse_clients_from_csv "$_CLIENTS_CSV")

    # Validar que sea número
    if [[ ! "$n" =~ ^[0-9]+$ ]]; then
        warn "Invalid client count: '${n}' -- assuming 0"
        n=0
    fi

    echo "$n"
}

# get_client_macs: returns client MACs of the AP (one per line, to stdout).
# Reads the dedicated client CSV produced by detect_clients.
get_client_macs() {
    if [[ ! -f "$_CLIENTS_CSV" ]]; then
        return 0
    fi

    awk -F',' -v ap="${TARGET^^}" '
        /^[[:space:]]*$/ { past=1; next }
        past && /^[0-9A-Fa-f]{2}:/ {
            for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
            if (toupper($6)==ap) print toupper($1)
        }' "$_CLIENTS_CSV" 2>/dev/null || true
}
