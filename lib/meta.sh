#!/usr/bin/env bash
# lib/meta.sh -- Metadata cache of scanned networks.
# Not executed directly. Loaded by the entrypoint.

sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' |
        tr -cs 'a-z0-9._-' '_' |
        sed 's/_\+/_/g; s/^_//; s/_$//'
}

init_meta() {
    # One-time migration from the legacy path (~/wssids) to the XDG
    # location. Silent when there is nothing to migrate; moves the
    # whole directory once and leaves no trace behind.
    if [[ ! -d "$META_DIR" && -d "$LEGACY_META_DIR" ]]; then
        mkdir -p "$(dirname "$META_DIR")" 2>/dev/null || true
        if mv "$LEGACY_META_DIR" "$META_DIR" 2>/dev/null; then
            dbg "Migrated ${LEGACY_META_DIR} -> ${META_DIR}"
        fi
    fi

    if [[ ! -d "$META_DIR" ]]; then
        mkdir -p "$META_DIR" || die "Could not create META_DIR: ${META_DIR}"
        chmod 700 "$META_DIR" 2>/dev/null || true
        ok "Metadata directory created: ${META_DIR}"
    else
        dbg "META_DIR exists: ${META_DIR}"
    fi
    META_FILE="${META_DIR}/$(sanitize_name "$TARGET").meta"
    dbg "Provisional META_FILE: ${META_FILE}"
}

update_meta_name() {
    if [[ -z "$SSID_NAME" ]]; then
        return 0
    fi
    local new
    new="${META_DIR}/$(sanitize_name "$SSID_NAME").meta"
    if [[ "$new" != "$META_FILE" && -f "$META_FILE" ]]; then
        mv -f "$META_FILE" "$new" 2>/dev/null || true
        dbg "META_FILE renamed -> ${new}"
    fi
    META_FILE="$new"
}

write_meta() {
    if [[ -z "$META_FILE" ]]; then
        return 0
    fi
    mkdir -p "$META_DIR" 2>/dev/null || true
    cat >"$META_FILE" <<EOF
# wai v${VER} -- metadata cache. Do not edit by hand.
WAI_VERSION=${VER}
TIMESTAMP=$(date '+%s')
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
SSID=${SSID_NAME}
BSSID=${TARGET}
CHANNEL=${CHANNEL}
IFACE=${IFACE}
OUTDIR=${OUTDIR}
HOSTNAME=$(hostname 2>/dev/null || echo unknown)
KERNEL=$(uname -r 2>/dev/null || echo unknown)
EOF
    chmod 600 "$META_FILE" 2>/dev/null || true
    ok "Metadata saved -> ${META_FILE}"
}

load_meta() {
    if [[ -z "$META_FILE" || ! -f "$META_FILE" ]]; then
        dbg "No META_FILE or file does not exist."
        return 1
    fi

    local ts bssid channel ssid_stored
    ts=$(grep '^TIMESTAMP=' "$META_FILE" | cut -d'=' -f2- | tr -d '[:space:]') ||
        {
            rm -f "$META_FILE"
            return 1
        }
    bssid=$(grep '^BSSID=' "$META_FILE" | cut -d'=' -f2- | tr -d '[:space:]') ||
        {
            rm -f "$META_FILE"
            return 1
        }
    channel=$(grep '^CHANNEL=' "$META_FILE" | cut -d'=' -f2- | tr -d '[:space:]') ||
        {
            rm -f "$META_FILE"
            return 1
        }
    ssid_stored=$(grep '^SSID=' "$META_FILE" | cut -d'=' -f2-) ||
        {
            rm -f "$META_FILE"
            return 1
        }

    if [[ -z "$ts" || -z "$bssid" || -z "$channel" ]]; then
        warn "Corrupt cache (empty fields) -- discarding."
        rm -f "$META_FILE"
        return 1
    fi
    if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
        warn "Corrupt cache (invalid timestamp) -- discarding."
        rm -f "$META_FILE"
        return 1
    fi
    if [[ ! "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        warn "Corrupt cache (invalid BSSID) -- discarding."
        rm -f "$META_FILE"
        return 1
    fi
    if [[ ! "$channel" =~ ^[0-9]+$ ]]; then
        warn "Corrupt cache (invalid channel) -- discarding."
        rm -f "$META_FILE"
        return 1
    fi

    local now age mins secs
    now=$(date '+%s')
    age=$((now - ts))
    mins=$((age / 60))
    secs=$((age % 60))

    TARGET="$bssid"
    CHANNEL="$channel"
    SSID_NAME="${ssid_stored}"
    update_meta_name

    if ((age > META_MAX_AGE)); then
        warn "Cache for '${ssid_stored}' expired (${mins}m ${secs}s)."
        META_LOADED=2
    else
        ok "Cache valid '${ssid_stored}' (${mins}m ${secs}s) -- scan skipped."
        META_LOADED=1
    fi
    return 0
}
