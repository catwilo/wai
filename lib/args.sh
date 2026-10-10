#!/usr/bin/env bash
# lib/args.sh — Parseo de argumentos por subcomando
# No ejecutar directamente. Cargado por wai

usage() {
    echo -e "${B}wai v${VER}${N} — WPA2 Handshake Capture CLI (solo redes autorizadas)" >&2
    echo -e "" >&2
    echo -e "  ${B}Uso:${N}  sudo wai <subcomando> [flags]" >&2
    echo -e "" >&2
    echo -e "  ${B}Subcomandos:${N}" >&2
    echo -e "    cap    Flujo completo: scan → monitor → deauth → captura → optimizar" >&2
    echo -e "    scan   Solo escanear y listar redes (sin tocar iwd)" >&2
    echo -e "    mon    Activar/desactivar modo monitor:  wai mon -i <iface> on|off" >&2
    echo -e "    deth   Deauth dirigido a un cliente:  wai deth -i <iface> -t <BSSID> -c <MAC>" >&2
    echo -e "    opt    Convertir .cap existentes:  wai opt -o <dir> <archivo.cap>..." >&2
    echo -e "" >&2
    echo -e "  ${B}Flags comunes:${N}" >&2
    echo -e "    -i  Interfaz física      (ej: wlan0)                         [cap|scan|mon|deth]" >&2
    echo -e "    -t  BSSID o SSID         (repetible en cap)                  [cap|deth]" >&2
    echo -e "    -c  Canal (cap/scan) · MAC cliente (deth)                    [cap|scan|deth]" >&2
    echo -e "    -o  Directorio salida    (por defecto: dir actual)           [cap|opt]" >&2
    echo -e "    -h  Esta ayuda" >&2
    echo -e "" >&2
    echo -e "  ${B}Ejemplos:${N}" >&2
    echo -e "    sudo wai cap -i wlan0 -t MiRed -t AA:BB:CC:DD:EE:FF" >&2
    echo -e "    sudo wai scan -i wlan0" >&2
    echo -e "    sudo wai mon -i wlan0 on" >&2
    echo -e "    sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66" >&2
    echo -e "    sudo wai opt -o /tmp/caps cap1.cap cap2.cap" >&2
    exit 0
}

banner() {
    local sub="$1"
    echo -e "\n${B}${C}  wai v${VER} — ${sub}${N}  ·  solo redes autorizadas" >&2
    echo -e "${DIM}  Shell: ${BASH}  PID: $$${N}\n" >&2
}

# _require_iface: -i obligatorio
_require_iface() {
    [[ -z "$IFACE" ]] && die "Falta argumento obligatorio: -i <interfaz>"
}

# _require_targets: al menos un -t
_require_targets() {
    [[ ${#TARGETS_RAW[@]} -eq 0 ]] && die "Falta argumento obligatorio: -t <BSSID|SSID>"
}

# _validate_channel: -c debe ser entero si está presente
_validate_channel() {
    [[ -n "$CHANNEL" && ! "$CHANNEL" =~ ^[0-9]+$ ]] \
        && die "El canal (-c) debe ser un número entero positivo."
}

# _validate_outdir: crea -o
_validate_outdir() {
    mkdir -p "$OUTDIR" || die "No se pudo crear el directorio de salida: ${OUTDIR}"
}

# ── parse_cap_args: -i, -t (repetible), -c, -o ─────────────────────────────────
parse_cap_args() {
    while getopts ":i:t:c:o:h" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            t) TARGETS_RAW+=("$OPTARG") ;;
            c) CHANNEL="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            h) usage ;;
            :) die "La opción -${OPTARG} requiere un argumento." ;;
            *) die "Opción desconocida: -${OPTARG}  (usa -h para ayuda)" ;;
        esac
    done
    _require_iface
    _require_targets
    _validate_channel
    _validate_outdir
    dbg "cap args: IFACE=${IFACE} TARGETS=(${TARGETS_RAW[*]}) CHANNEL=${CHANNEL:-auto} OUTDIR=${OUTDIR}"
}

# ── parse_scan_args: -i, -c (opcional, solo para resolver target), -o ──────────
parse_scan_args() {
    while getopts ":i:c:o:h" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            c) CHANNEL="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            h) usage ;;
            :) die "La opción -${OPTARG} requiere un argumento." ;;
            *) die "Opción desconocida: -${OPTARG}  (usa -h para ayuda)" ;;
        esac
    done
    _require_iface
    _validate_channel
    _validate_outdir
    dbg "scan args: IFACE=${IFACE} CHANNEL=${CHANNEL:-auto}"
}

# ── parse_mon_args: -i, acción posicional on|off ───────────────────────────────
parse_mon_args() {
    MON_ACTION=""
    while getopts ":i:h" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            h) usage ;;
            :) die "La opción -${OPTARG} requiere un argumento." ;;
            *) die "Opción desconocida: -${OPTARG}  (usa -h para ayuda)" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    MON_ACTION="${1:-}"
    _require_iface
    case "$MON_ACTION" in
        on|off) ;;
        "") die "Uso: wai mon -i <iface> on|off" ;;
        *) die "Acción inválida: '${MON_ACTION}'  (usa 'on' u 'off')" ;;
    esac
    dbg "mon args: IFACE=${IFACE} ACTION=${MON_ACTION}"
}

# ── parse_deth_args: -i, -t (BSSID), -c (cliente MAC), -o ──────────────────────
parse_deth_args() {
    CLIENT_MAC=""
    while getopts ":i:t:c:o:h" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            t) TARGETS_RAW+=("$OPTARG") ;;
            c) CLIENT_MAC="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            h) usage ;;
            :) die "La opción -${OPTARG} requiere un argumento." ;;
            *) die "Opción desconocida: -${OPTARG}  (usa -h para ayuda)" ;;
        esac
    done
    _require_iface
    _require_targets
    [[ ${#TARGETS_RAW[@]} -gt 1 ]] && die "deth solo acepta un -t (BSSID del AP)"
    BSSID="${TARGETS_RAW[0]}"
    [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] \
        && die "deth requiere un BSSID válido en -t (AA:BB:CC:DD:EE:FF)"
    [[ -z "$CLIENT_MAC" ]] && die "Falta -c <MAC del cliente>"
    [[ ! "$CLIENT_MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] \
        && die "deth requiere una MAC válida en -c (AA:BB:CC:DD:EE:FF)"
    _validate_outdir
    dbg "deth args: IFACE=${IFACE} BSSID=${BSSID} CLIENT_MAC=${CLIENT_MAC}"
}

# ── parse_opt_args: -o (dir salida, opcional), archivos posicionales ───────────
parse_opt_args() {
    declare -g -a OPT_FILES=()
    while getopts ":o:h" opt; do
        case $opt in
            o) OUTDIR="$OPTARG" ;;
            h) usage ;;
            :) die "La opción -${OPTARG} requiere un argumento." ;;
            *) die "Opción desconocida: -${OPTARG}  (usa -h para ayuda)" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    OPT_FILES=("$@")
    [[ ${#OPT_FILES[@]} -eq 0 ]] && die "Uso: wai opt [-o <dir>] <archivo.cap>..."
    _validate_outdir
    dbg "opt args: OUTDIR=${OUTDIR} FILES=(${OPT_FILES[*]})"
}
