#!/usr/bin/env bats
# monitor.bats -- comportamiento de los chequeos de seguridad en monitor.sh.
# Invocan las funciones con estado controlado; no tocan el sistema real.

load helpers

setup() {
    setup_env

    # Stubs minimos que monitor.sh espera del resto del CLI
    dbg()  { :; }
    info() { :; }
    ok()   { :; }
    warn() { echo "warn: $*" >&2; }
    hdr()  { :; }
    die()  { echo "die: $*" >&2; return 1; }
    export -f dbg info ok warn hdr die 2>/dev/null || true

    # shellcheck source=/dev/null
    source "$REPO/lib/monitor.sh"
}

# --- _wai_ssh_iface ---

@test "_wai_ssh_iface: sin SSH_CONNECTION -> return 1" {
    unset SSH_CONNECTION
    run _wai_ssh_iface
    [ "$status" -ne 0 ]
}

# --- _monitor_safety_check: la iface lleva SSH ---

@test "_monitor_safety_check: iface lleva SSH actual -> die" {
    export SSH_CONNECTION="1.2.3.4 50000 10.0.0.5 22"
    ip() {
        if [[ "$1" == "-o" && "$2" == "addr" ]]; then
            echo "3: wlan0    inet 10.0.0.5/24 scope global wlan0"
        fi
    }
    export -f ip 2>/dev/null || true

    run _monitor_safety_check "wlan0"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lleva la sesion SSH"* ]]
}

# --- _monitor_safety_check: sin alternativa, sin FORCE ---

@test "_monitor_safety_check: sin otra wifi con IP y sin WAI_FORCE -> die" {
    unset SSH_CONNECTION
    unset WAI_FORCE

    _wai_other_wifi_iface_with_ip() {
        return 1
    }

    run _monitor_safety_check "wlan0"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no hay otra antena"* ]]
}

@test "_monitor_safety_check: sin otra wifi con IP pero WAI_FORCE=1 -> continua" {
    unset SSH_CONNECTION
    export WAI_FORCE=1

    _wai_other_wifi_iface_with_ip() {
        return 1
    }

    run _monitor_safety_check "wlan0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"continuando por WAI_FORCE=1"* ]]
}
