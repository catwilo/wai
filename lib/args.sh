#!/usr/bin/env bash
# lib/args.sh -- Per-subcommand argument parsing.
# Not executed directly. Loaded by the entrypoint.
#
# Every parse_<sub>_args fills the global state and calls the relevant
# validators. All parsers accept -h (usage), -V (version), -n (dry-run).

usage() {
    cat >&2 <<'USAGE'
wai -- WPA2 Handshake Capture CLI (authorized networks only)

  Usage:  sudo wai <subcommand> [flags]

  Subcommands:
    cap    Full flow: scan -> monitor -> deauth -> capture -> optimize
    scan   Scan and list visible networks only
    mon    Enable/disable monitor mode:  wai mon -i <iface> on|off
    deth   Directed deauth to one client:  wai deth -i <iface> -t <BSSID> -c <MAC>
    opt    Convert existing .cap files:  wai opt -o <dir> <file.cap>...

  Common flags:
    -i  Physical interface     (e.g. wlan0)                       [cap|scan|mon|deth]
    -t  BSSID or SSID          (repeatable on cap)                [cap|deth]
    -c  Channel (cap/scan) - client MAC (deth)                    [cap|scan|deth]
    -o  Output directory       (default: current dir)             [cap|opt]
    -n  Dry-run: print actions, change nothing                    [all]
    -h  This help                                                 [all]
    -V  Version                                                   [all]

  Examples:
    sudo wai cap -i wlan0 -t MyNet -t AA:BB:CC:DD:EE:FF
    sudo wai cap -i wlan0 -t MyNet --dry-run
    sudo wai scan -i wlan0
    sudo wai mon -i wlan0 on
    sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66
    sudo wai opt -o ~/caps cap1.cap cap2.cap
USAGE
    exit 0
}

version() {
    echo "wai v${VER}"
    exit 0
}

banner() {
    local sub="$1"
    echo -e "\n${B}${C}  wai v${VER} -- ${sub}${N}  |  authorized networks only" >&2
    echo -e "${DIM}  Shell: ${BASH}${N}\n" >&2
}

_require_iface() {
    # Idiomatic under `set -e`: use `||` so a satisfied condition is
    # a success (rc=0), not a bare `[[ ... ]] &&` whose false result
    # would abort the script.
    [[ -n "$IFACE" ]] || die "Missing required argument: -i <interface>"
}

_require_targets() {
    [[ ${#TARGETS_RAW[@]} -gt 0 ]] \
        || die "Missing required argument: -t <BSSID|SSID>"
}

_validate_channel() {
    if [[ -n "$CHANNEL" && ! "$CHANNEL" =~ ^[0-9]+$ ]]; then
        die "Channel (-c) must be a positive integer."
    fi
}

_validate_outdir() {
    mkdir -p "$OUTDIR" || die "Could not create output directory: ${OUTDIR}"
}

parse_cap_args() {
    while getopts ":i:t:c:o:nVh" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            t) TARGETS_RAW+=("$OPTARG") ;;
            c) CHANNEL="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            n) WAI_DRY_RUN=1 ;;
            V) version ;;
            h) usage ;;
            :) die "Option -${OPTARG} requires an argument." ;;
            *) die "Unknown option: -${OPTARG}  (use -h for help)" ;;
        esac
    done
    _require_iface
    _require_targets
    _validate_channel
    _validate_outdir
    dbg "cap args: IFACE=${IFACE} TARGETS=(${TARGETS_RAW[*]}) CHANNEL=${CHANNEL:-auto} OUTDIR=${OUTDIR} DRY=${WAI_DRY_RUN}"
}

parse_scan_args() {
    while getopts ":i:c:o:nVh" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            c) CHANNEL="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            n) WAI_DRY_RUN=1 ;;
            V) version ;;
            h) usage ;;
            :) die "Option -${OPTARG} requires an argument." ;;
            *) die "Unknown option: -${OPTARG}  (use -h for help)" ;;
        esac
    done
    _require_iface
    _validate_channel
    _validate_outdir
    dbg "scan args: IFACE=${IFACE} CHANNEL=${CHANNEL:-auto} DRY=${WAI_DRY_RUN}"
}

parse_mon_args() {
    MON_ACTION=""
    while getopts ":i:nVh" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            n) WAI_DRY_RUN=1 ;;
            V) version ;;
            h) usage ;;
            :) die "Option -${OPTARG} requires an argument." ;;
            *) die "Unknown option: -${OPTARG}  (use -h for help)" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    MON_ACTION="${1:-}"
    _require_iface
    case "$MON_ACTION" in
        on|off) ;;
        "") die "Usage: wai mon -i <iface> on|off" ;;
        *) die "Invalid action: '${MON_ACTION}'  (use 'on' or 'off')" ;;
    esac
    dbg "mon args: IFACE=${IFACE} ACTION=${MON_ACTION} DRY=${WAI_DRY_RUN}"
}

parse_deth_args() {
    CLIENT_MAC=""
    while getopts ":i:t:c:o:nVh" opt; do
        case $opt in
            i) IFACE="$OPTARG" ;;
            t) TARGETS_RAW+=("$OPTARG") ;;
            c) CLIENT_MAC="$OPTARG" ;;
            o) OUTDIR="$OPTARG" ;;
            n) WAI_DRY_RUN=1 ;;
            V) version ;;
            h) usage ;;
            :) die "Option -${OPTARG} requires an argument." ;;
            *) die "Unknown option: -${OPTARG}  (use -h for help)" ;;
        esac
    done
    _require_iface
    _require_targets
    if [[ ${#TARGETS_RAW[@]} -gt 1 ]]; then
        die "deth accepts only one -t (AP BSSID)"
    fi
    BSSID="${TARGETS_RAW[0]}"
    if [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        die "deth requires a valid BSSID in -t (AA:BB:CC:DD:EE:FF)"
    fi
    if [[ -z "$CLIENT_MAC" ]]; then
        die "Missing -c <client MAC>"
    fi
    if [[ ! "$CLIENT_MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        die "deth requires a valid MAC in -c (AA:BB:CC:DD:EE:FF)"
    fi
    _validate_outdir
    dbg "deth args: IFACE=${IFACE} BSSID=${BSSID} CLIENT_MAC=${CLIENT_MAC} DRY=${WAI_DRY_RUN}"
}

parse_opt_args() {
    declare -g -a OPT_FILES=()
    while getopts ":o:nVh" opt; do
        case $opt in
            o) OUTDIR="$OPTARG" ;;
            n) WAI_DRY_RUN=1 ;;
            V) version ;;
            h) usage ;;
            :) die "Option -${OPTARG} requires an argument." ;;
            *) die "Unknown option: -${OPTARG}  (use -h for help)" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    OPT_FILES=("$@")
    if [[ ${#OPT_FILES[@]} -eq 0 ]]; then
        die "Usage: wai opt [-o <dir>] <file.cap>..."
    fi
    _validate_outdir
    dbg "opt args: OUTDIR=${OUTDIR} FILES=(${OPT_FILES[*]}) DRY=${WAI_DRY_RUN}"
}
