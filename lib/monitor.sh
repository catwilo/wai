#!/usr/bin/env bash
# lib/monitor.sh -- Monitor mode via wifi-setup backend.
# Not executed directly. Loaded by the entrypoint.
#
# RESPONSABILIDAD: delegar el cambio managed<->monitor a wifi-setup.
# wai NO toca el stack de red (NetworkManager, iwd, dhcpcd, iw) directo.
# El backend aplica el cambio y devuelve la iface a managed al salir.
#
# monitor_up   pone IFACE en modo monitor (via `wifi monitor on`).
# monitor_down devuelve IFACE a managed (via `wifi monitor off`).
#
# Bajo dry-run, no llama a wifi-setup: imprime la accion y asigna MON.
# Bajo WAI_DRY_RUN=1 igual se valida que wifi-setup exista.


# ---------------------------------------------------------------------------
# _wai_ssh_iface -- imprime la iface por la que entra SSH, o vacio.
# Usa SSH_CONNECTION (client_ip client_port server_ip server_port): busca
# cual iface local tiene esa IP.
# ---------------------------------------------------------------------------
_wai_ssh_iface() {
    [[ -n "${SSH_CONNECTION:-}" ]] || return 1
    local server_ip iface
    server_ip="$(awk '{print $3}' <<< "${SSH_CONNECTION}")"
    [[ -n "${server_ip}" ]] || return 1
    iface="$(ip -o addr show 2>/dev/null \
        | awk -v ip="${server_ip}" '$4 ~ "^"ip"/" {print $2; exit}')"
    [[ -n "${iface}" ]] || return 1
    echo "${iface}"
}

# ---------------------------------------------------------------------------
# _wai_iface_has_ip <iface> -- 0 si la iface tiene una IPv4.
# ---------------------------------------------------------------------------
_wai_iface_has_ip() {
    ip -4 -o addr show "$1" 2>/dev/null | awk '{print $4}' | grep -q .
}

# ---------------------------------------------------------------------------
# _wai_other_wifi_iface_with_ip <exclude> -- imprime otra iface WiFi con IP.
# ---------------------------------------------------------------------------
_wai_other_wifi_iface_with_ip() {
    local exclude="$1" iface
    local path base
    for path in /sys/class/net/wl*; do
        [[ -e "${path}" ]] || continue
        base="${path##*/}"
        [[ "${base}" == "${exclude}" ]] && continue
        _wai_iface_has_ip "${base}" && { echo "${base}"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
# _monitor_safety_check <iface> -- aborta o advierte segun el caso.
#   - Si la iface lleva la sesion SSH actual -> die (siempre).
#   - Si no hay otra antena WiFi con IP -> warn; solo continua con WAI_FORCE=1.
# ---------------------------------------------------------------------------
_monitor_safety_check() {
    local iface="$1"

    # 1. La iface lleva la sesion SSH actual: cortar SIEMPRE.
    local ssh_iface
    if ssh_iface="$(_wai_ssh_iface 2>/dev/null)"; then
        if [[ "${ssh_iface}" == "${iface}" ]]; then
            die "la iface '${iface}' lleva la sesion SSH actual -- ponerla en monitor corta el acceso remoto.\n  usa otra antena (-i <otra>), o pasa por consola fisica con WAI_FORCE=1"
        fi
    fi

    # 2. No hay otra antena con IP: advertir, exigir confirmacion.
    local other
    if other="$(_wai_other_wifi_iface_with_ip "${iface}" 2>/dev/null)"; then
        dbg "acceso alternativo disponible: ${other}"
        return 0
    fi

    if [[ "${WAI_FORCE:-0}" == "1" ]]; then
        warn "sin otra antena WiFi con IP -- continuando por WAI_FORCE=1"
        return 0
    fi

    die "no hay otra antena WiFi con IP; poner '${iface}' en monitor puede cortar el acceso.\n  si tenes consola fisica, reintenta con: WAI_FORCE=1 sudo wai <subcomando>"
}

monitor_up() {
    hdr "Monitor Mode"

    local target_iface="${IFACE}"
    [[ -n "${target_iface}" ]] || die "monitor_up: IFACE no seteada"

    if [[ "${WAI_DRY_RUN}" == "1" ]]; then
        dbg "[dry-run] wifi monitor on ${target_iface}"
        MON="${target_iface}"
        ok "Monitor interface (dry-run): ${MON}"
        return 0
    fi

    command -v wifi >/dev/null 2>&1 \
        || die "wifi no encontrado -- instala wifi-setup primero: ut distribute --install wifi-setup"

    _monitor_safety_check "${target_iface}"

    info "delegando a wifi-setup: monitor on ${target_iface}"
    wifi monitor on "${target_iface}" \
        || die "wifi monitor on ${target_iface} fallo -- revisa: sudo wifi doctor"

    MON="${target_iface}"
    ok "Monitor interface active: ${MON}"
}

monitor_down() {
    hdr "Disabling monitor mode"

    local target_iface="${MON:-${IFACE}}"
    [[ -n "${target_iface}" ]] || { warn "monitor_down: sin iface, nada que hacer"; return 0; }

    if [[ "${WAI_DRY_RUN}" == "1" ]]; then
        dbg "[dry-run] wifi monitor off ${target_iface}"
        MON=""
        return 0
    fi

    command -v wifi >/dev/null 2>&1 || {
        warn "wifi no encontrado -- no se puede devolver ${target_iface} a managed"
        MON=""
        return 0
    }

    info "delegando a wifi-setup: monitor off ${target_iface}"
    wifi monitor off "${target_iface}" \
        || warn "wifi monitor off ${target_iface} fallo -- revisa: sudo wifi monitor status"
    MON=""
    ok "Monitor mode disabled."
}
