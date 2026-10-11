#!/usr/bin/env bash
# lib/cleanup.sh -- Resource cleanup and system restore.
# Not executed directly. Loaded by the entrypoint.
#
# cleanup() es el unico exit handler, registrado por install_trap despues
# del preflight. Invocaciones que no tocan el sistema (usage, -h, -V) no
# lo instalan y no imprimen ruido al salir.
#
# cleanup delega el restablecimiento del modo monitor a wifi-setup
# (`wifi monitor off`), que es quien controla el stack de red. wai no
# toca NetworkManager, iwd, dhcpcd ni iw.

cleanup() {
    local rc=$?
    echo "" >&2
    warn "Cleaning up..."

    # Matar capturadores que puedan haber quedado vivos.
    pkill -9 -f "airodump-ng|aireplay-ng" 2>/dev/null || true
    sleep 1

    # Devolver la iface a managed (delegado a wifi-setup).
    if [[ -n "${MON}" ]]; then
        monitor_down || true
    fi

    rm -rf "${TMP}"
    if [[ ${rc} -eq 0 ]]; then
        ok "Finished OK (rc=0)."
    else
        warn "Finished with errors (rc=${rc})."
    fi
}

install_trap() {
    trap cleanup EXIT
    trap 'warn "INT/TERM received."; exit 130' INT TERM
}
