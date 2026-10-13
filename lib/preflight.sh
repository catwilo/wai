#!/usr/bin/env bash
# lib/preflight.sh -- Pre-flight verification.
# Not executed directly. Loaded by the entrypoint.
#
# preflight <sub>  -- checks the requirements for that subcommand:
#   cap  -> root + airodump-ng, aireplay-ng, aircrack-ng, wpaclean, wifi
#   scan -> root + airodump-ng, wifi
#   mon  -> root + wifi
#   deth -> root + airodump-ng, aireplay-ng, wifi
#   opt  -> no root + wpaclean
#   run  -> same as cap
#
# Optional tools (hcxpcapngtool, cap2hccapx, tshark) are detected once
# and stored in HAS_* regardless of subcommand.
#
# iwctl and airmon-ng are NOT dependencies: monitor mode is delegated to
# wifi-setup, which owns the network stack.

_preflight_requires_root() {
    case "$1" in
    opt) return 1 ;;
    *)   return 0 ;;
    esac
}

_preflight_deps_for() {
    case "$1" in
    cap | run) printf '%s\n' "airodump-ng aireplay-ng aircrack-ng wpaclean wifi" ;;
    scan)      printf '%s\n' "airodump-ng wifi" ;;
    mon)       printf '%s\n' "wifi" ;;
    deth)      printf '%s\n' "airodump-ng aireplay-ng wifi" ;;
    opt)       printf '%s\n' "wpaclean" ;;
    *)         printf '' ;;
    esac
}

preflight() {
    local sub="${1:-cap}"
    hdr "Pre-flight"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        warn "DRY-RUN: no system changes will be made."
    fi

    if _preflight_requires_root "$sub"; then
        if [[ $(id -u) -ne 0 ]]; then
            if [[ "$WAI_DRY_RUN" == "1" ]]; then
                warn "Not root; continuing because --dry-run is set."
            else
                die "This command requires root: sudo wai ${sub} ..."
            fi
        else
            ok "Root: OK"
        fi
    else
        dbg "Root not required for '${sub}'."
    fi

    if [[ "$WAI_DRY_RUN" != "1" ]]; then
        local miss=()
        local dep
        for dep in $(_preflight_deps_for "$sub"); do
            if command -v "$dep" &>/dev/null; then
                dbg "  dep OK: $dep -> $(command -v "$dep")"
            else
                miss+=("$dep")
            fi
        done
        ((${#miss[@]} > 0)) &&
            die "Missing dependencies for '${sub}': ${miss[*]}\n  -> aircrack-ng: sudo apt install aircrack-ng\n  -> wifi-setup: ut distribute --install wifi-setup"
        ok "Required dependencies: OK"
    else
        dbg "Dependencies: skipped (dry-run)."
    fi

    local opt
    for opt in hcxpcapngtool cap2hccapx tshark; do
        if command -v "$opt" &>/dev/null; then
            dbg "  optional OK: $opt -> $(command -v "$opt")"
            case "$opt" in
            hcxpcapngtool) HAS_HCXPCAPNGTOOL=1 ;;
            cap2hccapx) HAS_CAP2HCCAPX=1 ;;
            tshark) HAS_TSHARK=1 ;;
            esac
        else
            dbg "  optional missing: $opt"
            case "$opt" in
            hcxpcapngtool | cap2hccapx)
                warn "Optional tool missing: $opt  (install: sudo apt install hcxtools)"
                ;;
            tshark)
                warn "Optional tool missing: tshark  (install: sudo apt install tshark)"
                ;;
            esac
        fi
    done

    dbg "HAS_HCXPCAPNGTOOL=${HAS_HCXPCAPNGTOOL}  HAS_CAP2HCCAPX=${HAS_CAP2HCCAPX}  HAS_TSHARK=${HAS_TSHARK}"
    dbg "Shell: ${BASH}  version: ${BASH_VERSION}"
    dbg "System: $(uname -a)"
    sep
}
