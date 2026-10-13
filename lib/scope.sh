#!/usr/bin/env bash
# lib/scope.sh -- Persistent list of authorized lab networks.
# Not executed directly. Loaded by the entrypoint.
#
# RESPONSABILIDAD UNICA: leer y escribir ~/.wai/scope, la lista de
# redes que el usuario autoriza para captura. Una red por linea
# (SSID o BSSID). '#' al inicio comenta. Lineas vacias se ignoran.
#
# Tambien define CAPTURES_DIR (~/.wai/captures), destino por defecto
# de las capturas producidas por `wai run`.
#
# Requiere: logging.sh (info/ok/warn/die).

readonly SCOPE_DIR="$HOME/.wai"
readonly SCOPE_FILE="$SCOPE_DIR/scope"
readonly CAPTURES_DIR="$SCOPE_DIR/captures"

# scope_init -- crea dir+archivo+permisos si faltan. Idempotente.
scope_init() {
    if [[ ! -d "$SCOPE_DIR" ]]; then
        mkdir -p "$SCOPE_DIR" || die "no pude crear $SCOPE_DIR"
        chmod 700 "$SCOPE_DIR"
    fi
    if [[ ! -f "$SCOPE_FILE" ]]; then
        : > "$SCOPE_FILE"
        chmod 600 "$SCOPE_FILE"
    fi
}

# scope_read -- emite solo las entradas validas a stdout.
scope_read() {
    [[ -f "$SCOPE_FILE" ]] || return 0
    awk '!/^[[:space:]]*#/ && NF' "$SCOPE_FILE"
}

# scope_add <entry> -- agrega una entrada unica. Rechaza vacios y
# lineas que empezarian con '#' (el archivo usa '#' para comentarios).
scope_add() {
    local entry="$1"
    [[ -n "$entry" ]] || die "scope add: entrada vacia"
    [[ "${entry:0:1}" == "#" ]] && die "scope add: '#' reservado para comentarios"
    scope_init
    if scope_read | grep -qxF "$entry"; then
        warn "ya esta en el scope: $entry"
        return 0
    fi
    printf '%s\n' "$entry" >> "$SCOPE_FILE"
    ok "scope += $entry"
}

# scope_rm <entry> -- quita una entrada por coincidencia exacta.
scope_rm() {
    local entry="$1"
    [[ -n "$entry" ]] || die "scope rm: entrada vacia"
    [[ -f "$SCOPE_FILE" ]] || { warn "no existe $SCOPE_FILE"; return 0; }
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/wai-scope.XXXXXX") || die "mktemp fallo"
    awk -v e="$entry" '$0 != e' "$SCOPE_FILE" > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$SCOPE_FILE"
    ok "scope -= $entry"
}

# scope_clear -- vacia el archivo tras confirmacion interactiva.
scope_clear() {
    [[ -f "$SCOPE_FILE" ]] || return 0
    if [[ -t 0 ]]; then
        printf 'vaciar %s ? [y/N] ' "$SCOPE_FILE" >&2
        local ans; read -r ans
        case "$ans" in y|Y) ;; *) info "cancelado"; return 0 ;; esac
    fi
    : > "$SCOPE_FILE"
    chmod 600 "$SCOPE_FILE"
    ok "scope vaciado"
}

# scope_show -- imprime ruta + contenido numerado. Header a stderr,
# entradas a stdout (para que `wai scope | xargs` sea util).
scope_show() {
    scope_init
    printf '%bscope%b\n' "${B}${C}" "${N}" >&2
    printf '  archivo : %s\n' "$SCOPE_FILE"   >&2
    printf '  capturas: %s\n' "$CAPTURES_DIR" >&2
    printf '\n' >&2
    local entries
    entries="$(scope_read)"
    if [[ -z "$entries" ]]; then
        warn "scope vacio -- agrega con: wai scope add <SSID|BSSID>"
        return 0
    fi
    local i=1
    while IFS= read -r l; do
        printf '  %2d) %s\n' "$i" "$l"
        i=$((i + 1))
    done <<< "$entries"
}

# scope_edit -- abre $EDITOR sobre el archivo. Fallback a vi.
scope_edit() {
    scope_init
    local ed="${EDITOR:-vi}"
    command -v "$ed" >/dev/null 2>&1 || die "editor no encontrado: $ed"
    "$ed" "$SCOPE_FILE"
    chmod 600 "$SCOPE_FILE" 2>/dev/null || true
}
