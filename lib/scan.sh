#!/usr/bin/env bash
# lib/scan.sh -- Network scan and BSSID/channel resolution.
# Not executed directly. Loaded by the entrypoint.

run_scan() {
    local duration="${1:-$SCAN_SEC}"
    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        dbg "[dry-run] airodump-ng scan (${duration}s) on $MON"
        return 0
    fi
    rm -f "${TMP}/scan-01.csv" 2>/dev/null || true
    info "Network scan (${duration}s) -> ${TMP}/scan.log"

    # Redirigir stdout+stderr a archivo — evita suspend en zsh y permite captura real
    airodump-ng \
        --output-format csv \
        --write "${TMP}/scan" \
        "$MON" >"${TMP}/scan.log" 2>&1 &
    local scan_pid=$!
    dbg "airodump-ng escaneo PID: ${scan_pid}"

    local i=0
    while kill -0 "$scan_pid" 2>/dev/null && ((i < duration)); do
        printf "\r  ${C}Scanning... %2ds${N}" "$((duration - i))" >&2
        sleep 1
        i=$((i + 1))
    done
    printf "\r  %sScan finished.            %s\n" "$C" "$N" >&2

    kill "$scan_pid" 2>/dev/null || true
    wait "$scan_pid" 2>/dev/null || true

    if [[ ! -f "${TMP}/scan-01.csv" ]]; then
        warn "airodump-ng log (scan):"
        while IFS= read -r l; do warn "  $l"; done <"${TMP}/scan.log" 2>/dev/null || true
        die "No CSV after scan. Is ${MON} in monitor mode and UP?"
    fi

    local ap_count
    ap_count=$(grep -c '^[0-9A-Fa-f]\{2\}:' "${TMP}/scan-01.csv" 2>/dev/null || echo 0)
    dbg "APs found in CSV: ${ap_count}"

    if [[ "$ap_count" -eq 0 ]]; then
        warn "Empty CSV. airodump-ng log:"
        while IFS= read -r l; do warn "  $l"; done <"${TMP}/scan.log" 2>/dev/null || true
        die "Scan produced no results. Is the interface in monitor mode?"
    fi
}

resolve_target() {
    hdr "Target resolution"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        # Simulate resolution without touching the network. Accept any
        # token as-is so the rest of the flow can be exercised.
        if [[ "$TARGET" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            TARGET="${TARGET^^}"
            if [[ -z "$SSID_NAME" ]]; then
                SSID_NAME="$TARGET"
            fi
        else
            SSID_NAME="$TARGET"
            TARGET="AA:BB:CC:DD:EE:FF"
        fi
        if [[ -z "$CHANNEL" ]]; then
            CHANNEL=6
        fi
        dbg "[dry-run] resolved: BSSID=${TARGET}  Channel=${CHANNEL}  SSID=${SSID_NAME}"
        ok "BSSID=${TARGET}  Channel=${CHANNEL}  SSID='${SSID_NAME}'  (dry-run)"
        return 0
    fi

    local is_bssid=0
    if [[ "$TARGET" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        is_bssid=1
    fi
    dbg "TARGET='${TARGET}'  is_bssid=${is_bssid}  META_LOADED=${META_LOADED}  CHANNEL='${CHANNEL}'"

    # Valid cache -- no scan needed
    if ((META_LOADED >= 1)) && [[ -n "$CHANNEL" ]]; then
        TARGET="${TARGET^^}"
        local src="fresh cache"
        if ((META_LOADED == 2)); then
            src="stale cache"
        fi
        ok "BSSID=${TARGET}  Channel=${CHANNEL}  SSID='${SSID_NAME}'  (${src})"
        return 0
    fi

    # BSSID and channel given directly as arguments
    if ((is_bssid)) && [[ -n "$CHANNEL" ]]; then
        TARGET="${TARGET^^}"
        if [[ -z "$SSID_NAME" ]]; then
            SSID_NAME="$TARGET"
        fi
        ok "BSSID=${TARGET}  Channel=${CHANNEL}  (direct args)"
        update_meta_name
        write_meta
        return 0
    fi

    # Scan needed
    run_scan
    local csv="${TMP}/scan-01.csv"

    if ((is_bssid)); then
        # Find channel by BSSID
        CHANNEL=$(awk -F',' -v b="${TARGET^^}" '
            /^[0-9A-Fa-f]{2}:/ {
                gsub(/ /,"",$1); gsub(/ /,"",$4)
                if (toupper($1)==b) { print $4; exit }
            }' "$csv")
        if [[ -z "$CHANNEL" ]]; then
            die "Channel not found for ${TARGET}. Use -c <channel>."
        fi

        local ssid_found
        ssid_found=$(awk -F',' -v b="${TARGET^^}" '
            /^[0-9A-Fa-f]{2}:/ {
                for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
                if (toupper($1)==b && $14!="") { print $14; exit }
            }' "$csv") || true
        SSID_NAME="${ssid_found:-$TARGET}"

    else
        # Find BSSID+channel by SSID name
        dbg "Looking for SSID '${TARGET}' in CSV..."
        local row
        row=$(awk -F',' -v s="$TARGET" '
            /^[0-9A-Fa-f]{2}:/ {
                for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
                if ($14==s && $6~/WPA/) { print $1"|"$4; exit }
            }' "$csv") || true

        if [[ -z "$row" ]]; then
            warn "SSID '${TARGET}' not found. Networks detected:"
            awk -F',' '/^[0-9A-Fa-f]{2}:/{
                for(i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i)
                if($14!="" && $14!="ESSID")
                    printf "  BSSID=%-20s  Ch=%-3s  Enc=%-10s  SSID=%s\n",$1,$4,$6,$14
            }' "$csv" | head -20 >&2
            die "SSID '${TARGET}' not found in scan."
        fi

        SSID_NAME="$TARGET"
        TARGET=$(cut -d'|' -f1 <<<"$row")
        CHANNEL=${CHANNEL:-$(cut -d'|' -f2 <<<"$row")}
        dbg "Resolved: BSSID=${TARGET}  CHANNEL=${CHANNEL}"
    fi

    TARGET="${TARGET^^}"
    update_meta_name
    ok "BSSID=${TARGET}  Channel=${CHANNEL}  SSID='${SSID_NAME}'"
    write_meta
}
