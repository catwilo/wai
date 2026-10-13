#!/usr/bin/env bash
# lib/help.sh -- Help text for every subcommand + the index.
# Not executed directly. Loaded by the entrypoint BEFORE args.sh.
#
# RESPONSABILIDAD UNICA: todo el texto de ayuda del CLI. Una funcion
# help_<sub> por subcomando y help_index para el indice. El dispatcher
# enruta -h/--help ANTES de preflight, asi 'wai <sub> -h' funciona sin
# root y sin disparar el trap de cleanup.
#
# Requiere: constants.sh (VER), logging.sh (colores C B N DIM G).

_help_title()   { printf '\n%bwai v%s%b -- %s\n' "${B}${C}" "${VER}" "${N}" "$*" >&2; }
_help_section() { printf '\n%b%s%b\n' "${B}${C}" "$*" "${N}" >&2; }
_help_key()     { printf '  %b%-15s%b %s\n' "${G}" "$1" "${N}" "$2" >&2; }
_help_item()    { printf '    %b%s%b\n' "${C}" "$*" "${N}" >&2; }
_help_note()    { printf '  %s\n' "$*" >&2; }
_help_dim()     { printf '  %b%s%b\n' "${DIM}" "$*" "${N}" >&2; }

# ---------------------------------------------------------------------------
# help_index -- indice general. Invocado por 'wai', 'wai -h', 'wai --help'.
# ---------------------------------------------------------------------------
help_index() {
    _help_title "WPA2 Handshake Capture CLI"
    _help_note  "AUTHORIZED NETWORKS ONLY -- educational / lab use."
    printf '\n' >&2
    _help_note  "Usage:  sudo wai <subcommand> [flags]"
    _help_note  "        wai <subcommand> -h        detailed help for one subcommand"

    _help_section "SUBCOMMANDS"
    _help_key "cap"  "Full flow: scan -> monitor -> deauth -> capture -> optimize"
    _help_key "scan" "Scan and list visible networks only"
    _help_key "mon"  "Enable/disable monitor:  wai mon -i <iface> on|off"
    _help_key "deth" "Directed deauth:  wai deth -i <iface> -t <BSSID> -c <MAC>"
    _help_key "opt"  "Convert existing .cap files:  wai opt -o <dir> <file.cap>..."

    _help_section "COMMON FLAGS"
    _help_key "-i" "Physical interface (e.g. wlan0)          [cap|scan|mon|deth]"
    _help_key "-t" "BSSID or SSID (repeatable on cap)        [cap|deth]"
    _help_key "-c" "Channel (cap/scan) / client MAC (deth)   [cap|scan|deth]"
    _help_key "-o" "Output directory (default: pwd)          [cap|opt]"
    _help_key "-n" "Dry-run: print actions, change nothing   [all]"
    _help_key "-h" "Help                                     [all]"
    _help_key "-V" "Version                                  [all]"

    _help_section "ROUTES (where things live)"
    _help_item "captures  <dir from -o>  or  \$(pwd)    .cap + .22000 / .hccapx + .info"
    _help_item "cache     ~/.local/share/wai/            metadata of scanned networks"
    _help_item "temp      \$TMPDIR/wai.XXXXXX              per-run scratch, deleted on exit"
    _help_dim  "Override capture dir with: -o <dir>"

    _help_section "INTERNAL ACTIONS (what each subcommand calls)"
    _help_key "cap"  "wifi monitor + airodump-ng + aireplay-ng + aircrack-ng + wpaclean"
    _help_key "scan" "wifi monitor + airodump-ng"
    _help_key "mon"  "wifi monitor on|off <iface>"
    _help_key "deth" "wifi monitor + airodump-ng + aireplay-ng"
    _help_key "opt"  "wpaclean + hcxpcapngtool / cap2hccapx  (local only, no network)"

    _help_section "EXAMPLES"
    _help_item "sudo wai cap -i wlan0 -t MiRed -t AA:BB:CC:DD:EE:FF"
    _help_item "sudo wai cap -i wlan0 -t MiRed -n             # dry-run, touches nothing"
    _help_item "sudo wai scan -i wlan0"
    _help_item "sudo wai mon -i wlan0 on"
    _help_item "sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66"
    _help_item "sudo wai opt -o ~/caps cap1.cap cap2.cap"

    _help_section "PER-SUBCOMMAND HELP"
    _help_item "wai cap -h   wai scan -h   wai mon -h   wai deth -h   wai opt -h"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_cap -- flujo completo.
# ---------------------------------------------------------------------------
help_cap() {
    _help_title "cap -- full handshake capture flow"
    printf '\n' >&2
    _help_note "  sudo wai cap -i <iface> -t <SSID|BSSID> [-t ...] [-c <ch>] [-o <dir>] [-n]"

    _help_section "WHAT IT DOES"
    _help_item "1. Resolve target: scan (SSID) or use metadata cache (BSSID)"
    _help_item "2. Enable monitor mode on <iface>  (delegated to 'wifi monitor on')"
    _help_item "3. Detect clients connected to the AP"
    _help_item "4. Parallel deauth (directed + broadcast) to force reauth"
    _help_item "5. Capture with airodump-ng"
    _help_item "6. Verify handshake with aircrack-ng (and tshark if available)"
    _help_item "7. Clean .cap with wpaclean"
    _help_item "8. Convert to .22000 (hashcat modern) or .hccapx (legacy)"
    _help_item "9. Restore iface to managed, print summary"

    _help_section "EXTERNAL TOOLS CALLED (in order)"
    _help_key "wifi"          "monitor on/off <iface>      network backend"
    _help_key "airodump-ng"   "scan + capture"
    _help_key "aireplay-ng"   "parallel deauth"
    _help_key "aircrack-ng"   "handshake verification"
    _help_key "wpaclean"      "clean the capture"
    _help_key "hcxpcapngtool" "-> .22000 (optional, preferred)"
    _help_key "cap2hccapx"    "-> .hccapx (optional, fallback)"
    _help_key "tshark"        "early EAPOL detection (optional)"

    _help_section "FILES WRITTEN"
    _help_item "<dir>/<ssid>_<MAC>.cap       clean pcap"
    _help_item "<dir>/<ssid>_<MAC>.22000     hashcat WPA2 modern (recommended)"
    _help_item "<dir>/<ssid>_<MAC>.hccapx    hashcat legacy"
    _help_item "<dir>/<ssid>_<MAC>.info      session metadata"
    _help_item "~/.local/share/wai/<net>.meta   per-network cache (TTL 30min)"
    _help_dim  "dir = -o <dir>  or  current working directory"

    _help_section "FLAGS"
    _help_key "-i <iface>"  "Physical WiFi interface (required)"
    _help_key "-t <target>" "SSID or BSSID of AP (required, repeatable)"
    _help_key "-c <ch>"     "Fixed channel (optional; else resolved by scan)"
    _help_key "-o <dir>"    "Output directory (default: pwd)"
    _help_key "-n"          "Dry-run: no network, no filesystem changes"
    _help_key "-h"          "This help"
    _help_key "-V"          "Version"

    _help_section "SAFETY"
    _help_item "Aborts if the iface carries the current SSH session."
    _help_item "Aborts if no other WiFi interface has an IP (WAI_FORCE=1 to override)."
    _help_item "EXIT trap always restores the iface to managed mode."

    _help_section "EXAMPLES"
    _help_item "sudo wai cap -i wlan0 -t MiRed"
    _help_item "sudo wai cap -i wlan0 -t MiRed -t AA:BB:CC:DD:EE:FF -o ~/caps"
    _help_item "sudo wai cap -i wlan0 -t MiRed -n        # dry-run"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_scan
# ---------------------------------------------------------------------------
help_scan() {
    _help_title "scan -- list visible networks"
    printf '\n' >&2
    _help_note "  sudo wai scan -i <iface> [-c <ch>] [-n]"

    _help_section "WHAT IT DOES"
    _help_item "1. Enable monitor mode on <iface>  (delegated to 'wifi monitor on')"
    _help_item "2. Scan for 20s with airodump-ng"
    _help_item "3. Print the CSV path so you can inspect it"
    _help_item "4. EXIT trap restores the iface to managed mode"

    _help_section "EXTERNAL TOOLS CALLED"
    _help_key "wifi"        "monitor on/off <iface>"
    _help_key "airodump-ng" "scan"

    _help_section "FILES WRITTEN"
    _help_item "\$TMPDIR/wai.XXXXXX/scan-01.csv   raw scan CSV (deleted on exit)"
    _help_dim  "Nothing persists after the command finishes."

    _help_section "FLAGS"
    _help_key "-i <iface>" "Physical WiFi interface (required)"
    _help_key "-c <ch>"    "Fixed channel (optional)"
    _help_key "-o <dir>"   "Output directory (currently unused; reserved)"
    _help_key "-n"         "Dry-run"
    _help_key "-h"         "This help"

    _help_section "EXAMPLES"
    _help_item "sudo wai scan -i wlan0"
    _help_item "sudo wai scan -i wlan0 -c 6"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_mon
# ---------------------------------------------------------------------------
help_mon() {
    _help_title "mon -- monitor mode toggle"
    printf '\n' >&2
    _help_note "  sudo wai mon -i <iface> on"
    _help_note "  sudo wai mon -i <iface> off"

    _help_section "WHAT IT DOES"
    _help_item "on:  delegates to 'wifi monitor on <iface>'. Exits without"
    _help_item "     restoring, so the iface STAYS in monitor across commands."
    _help_item "off: delegates to 'wifi monitor off <iface>'. Restores managed."
    _help_item "wai never touches NetworkManager, iwd, dhcpcd or iw directly."

    _help_section "EXTERNAL TOOLS CALLED"
    _help_key "wifi" "monitor on|off <iface>"

    _help_section "SAFETY"
    _help_item "Aborts if the iface carries the current SSH session."
    _help_item "Aborts if no other WiFi interface has an IP (WAI_FORCE=1 to override)."

    _help_section "FLAGS"
    _help_key "-i <iface>" "Physical WiFi interface (required)"
    _help_key "on|off"     "Action (positional, required)"
    _help_key "-n"         "Dry-run"
    _help_key "-h"         "This help"

    _help_section "EXAMPLES"
    _help_item "sudo wai mon -i wlan0 on"
    _help_item "sudo wai mon -i wlan0 off"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_deth
# ---------------------------------------------------------------------------
help_deth() {
    _help_title "deth -- directed deauth to one client"
    printf '\n' >&2
    _help_note "  sudo wai deth -i <iface> -t <BSSID> -c <client-MAC> [-n]"

    _help_section "WHAT IT DOES"
    _help_item "1. Enable monitor mode on <iface>  (delegated to 'wifi monitor on')"
    _help_item "2. Resolve channel by scanning (unless you pass -c as channel)"
    _help_item "3. Send 8 directed deauth frames to the target client via aireplay-ng"
    _help_item "4. EXIT trap restores the iface to managed mode"

    _help_section "EXTERNAL TOOLS CALLED"
    _help_key "wifi"        "monitor on/off <iface>"
    _help_key "airodump-ng" "channel resolution"
    _help_key "aireplay-ng" "deauth"

    _help_section "WHY DIRECTED (and not broadcast)"
    _help_item "Modern APs and PMF (802.11w) clients filter unauthenticated"
    _help_item "broadcast deauth. Directed deauth per client MAC forces"
    _help_item "individual reauth -- the only technique that works against"
    _help_item "modern WPA2 stacks."

    _help_section "FLAGS"
    _help_key "-i <iface>"   "Physical WiFi interface (required)"
    _help_key "-t <BSSID>"   "AP BSSID as AA:BB:CC:DD:EE:FF (required, one only)"
    _help_key "-c <MAC>"     "Client MAC as AA:BB:CC:DD:EE:FF (required)"
    _help_key "-o <dir>"     "Output directory (default: pwd)"
    _help_key "-n"           "Dry-run"
    _help_key "-h"           "This help"

    _help_section "EXAMPLES"
    _help_item "sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_opt
# ---------------------------------------------------------------------------
help_opt() {
    _help_title "opt -- convert existing .cap files"
    printf '\n' >&2
    _help_note "  wai opt [-o <dir>] <file.cap>..."

    _help_section "WHAT IT DOES"
    _help_item "1. Clean each .cap with wpaclean"
    _help_item "2. Convert to .22000 with hcxpcapngtool (preferred)"
    _help_item "3. Fall back to .hccapx with cap2hccapx"
    _help_item "4. Always write a .cap (clean) and a .info (metadata)"
    _help_item "Does NOT need root, does NOT touch the network."

    _help_section "EXTERNAL TOOLS CALLED"
    _help_key "wpaclean"      "clean the capture"
    _help_key "hcxpcapngtool" "-> .22000 (optional, preferred)"
    _help_key "cap2hccapx"    "-> .hccapx (optional, fallback)"

    _help_section "FILES WRITTEN"
    _help_item "<dir>/<ssid>_<MAC>.cap       clean pcap"
    _help_item "<dir>/<ssid>_<MAC>.22000     hashcat WPA2 modern"
    _help_item "<dir>/<ssid>_<MAC>.hccapx    hashcat legacy"
    _help_item "<dir>/<ssid>_<MAC>.info      metadata"

    _help_section "FLAGS"
    _help_key "-o <dir>" "Output directory (default: pwd)"
    _help_key "-n"       "Dry-run"
    _help_key "-h"       "This help"

    _help_section "EXAMPLES"
    _help_item "wai opt -o ~/caps capture1.cap capture2.cap"
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# version -- --version / -V.
# ---------------------------------------------------------------------------
version() {
    echo "wai v${VER}"
    exit 0
}

# ---------------------------------------------------------------------------
# help_scope
# ---------------------------------------------------------------------------
help_scope() {
    _help_title "scope -- list of authorized lab networks"
    printf '\n' >&2
    _help_note "  wai scope                  show path + entries"
    _help_note "  wai scope edit             open \$EDITOR on the file"
    _help_note "  wai scope add <SSID|BSSID> append an entry"
    _help_note "  wai scope rm  <SSID|BSSID> remove an entry"
    _help_note "  wai scope clear            empty the file (asks for confirmation)"

    _help_section "WHAT IT DOES"
    _help_item "Manages ~/.wai/scope: a plain-text list of networks you"
    _help_item "authorize for capture. One entry per line (SSID or BSSID)."
    _help_item "Lines starting with '#' are comments. Blank lines are ignored."
    _help_item "Editing with a normal editor is expected and supported."

    _help_section "FILES"
    _help_item "~/.wai/scope       the list (mode 600)"
    _help_item "~/.wai/            parent dir (mode 700)"
    _help_item "~/.wai/captures/   output dir for 'wai run' (mode 700)"

    _help_section "SAFETY"
    _help_item "'wai scan' NEVER writes here. You promote entries by hand,"
    _help_item "so no network is captured without an explicit decision."
    printf '\n' >&2
}

# ---------------------------------------------------------------------------
# help_run
# ---------------------------------------------------------------------------
help_run() {
    _help_title "run -- capture every network in the scope"
    printf '\n' >&2
    _help_note "  sudo wai run -i <iface> [-o <dir>] [-n]"

    _help_section "WHAT IT DOES"
    _help_item "1. Read ~/.wai/scope (comments and blank lines ignored)."
    _help_item "2. For each entry, run the full 'cap' flow in order."
    _help_item "3. Store every .cap / .22000 / .hccapx / .info in the"
    _help_item "   output directory (default ~/.wai/captures/run-<ts>/)."
    _help_item "4. Print one consolidated summary at the end."

    _help_section "FILES WRITTEN"
    _help_item "<dir>/<ssid>_<MAC>.cap / .22000 / .hccapx / .info"
    _help_dim  "dir = -o <dir>  or  ~/.wai/captures/run-<YYYYMMDD-HHMMSS>/"

    _help_section "FLAGS"
    _help_key "-i <iface>" "Physical WiFi interface (required)"
    _help_key "-o <dir>"   "Output directory (default: ~/.wai/captures/run-<ts>/)"
    _help_key "-n"         "Dry-run: no network, no filesystem changes"
    _help_key "-h"         "This help"
    _help_key "-V"         "Version"

    _help_section "EXAMPLES"
    _help_item "wai scope add MiRed"
    _help_item "wai scope add AA:BB:CC:DD:EE:FF"
    _help_item "sudo wai run -i wlan0"
    _help_item "sudo wai run -i wlan0 -n        # dry-run"
    printf '\n' >&2
}
