#!/usr/bin/env bash
# lib/preflight.sh -- Pre-flight verification.
# Not executed directly. Loaded by the entrypoint.
#
# preflight <mode>:
#   root      require euid 0 (default for cap, scan, mon, deth)
#   no_root   only verify dependencies (default for opt)
#
# Optional tools (hcxpcapngtool, cap2hccapx, tshark) are detected here
# exactly once and stored in HAS_* variables. No other module calls
# `command -v` on them.

preflight() {
    local mode="${1:-root}"
    hdr "Pre-flight"

    if [[ "$WAI_DRY_RUN" == "1" ]]; then
        warn "DRY-RUN: no system changes will be made."
    fi

    if [[ "$mode" == "root" ]]; then
        if [[ $(id -u) -ne 0 ]]; then
            if [[ "$WAI_DRY_RUN" == "1" ]]; then
                warn "Not root; continuing because --dry-run is set."
            else
                die "This command requires root: sudo wai <sub> ..."
            fi
        else
            ok "Root: OK"
        fi
    else
        dbg "Root not required for this subcommand."
    fi

    if [[ "$WAI_DRY_RUN" != "1" ]]; then
        local miss=()
        for dep in airmon-ng airodump-ng aireplay-ng aircrack-ng wpaclean iwctl; do
            if command -v "$dep" &>/dev/null; then
                dbg "  dep OK: $dep -> $(command -v "$dep")"
            else
                miss+=("$dep")
            fi
        done
        (( ${#miss[@]} > 0 )) \
            && die "Missing dependencies: ${miss[*]}\n  -> sudo apt install aircrack-ng iwd"
        ok "Required dependencies: OK"
    else
        dbg "Dependencies: skipped (dry-run)."
    fi

    for opt in hcxpcapngtool cap2hccapx tshark; do
        if command -v "$opt" &>/dev/null; then
            dbg "  optional OK: $opt -> $(command -v "$opt")"
            case "$opt" in
                hcxpcapngtool) HAS_HCXPCAPNGTOOL=1 ;;
                cap2hccapx)    HAS_CAP2HCCAPX=1    ;;
                tshark)        HAS_TSHARK=1         ;;
            esac
        else
            dbg "  optional missing: $opt"
            case "$opt" in
                hcxpcapngtool|cap2hccapx)
                    warn "Optional tool missing: $opt  (install: sudo apt install hcxtools)" ;;
                tshark)
                    warn "Optional tool missing: tshark  (install: sudo apt install tshark)" ;;
            esac
        fi
    done

    dbg "HAS_HCXPCAPNGTOOL=${HAS_HCXPCAPNGTOOL}  HAS_CAP2HCCAPX=${HAS_CAP2HCCAPX}  HAS_TSHARK=${HAS_TSHARK}"
    dbg "Shell: ${BASH}  version: ${BASH_VERSION}"
    dbg "System: $(uname -a)"
    sep
}
