#!/usr/bin/env bats
# args.bats -- per-subcommand argument parsing and validation.
# Every parser runs BEFORE preflight, so these failures need no root
# and no hardware.

load helpers

setup() { setup_env; }

# --- scan ---

@test "scan: missing -i dies with actionable message" {
    run bash "$WAI" scan -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required argument: -i"* ]]
}

@test "scan: non-numeric channel dies" {
    run bash "$WAI" scan -i wlan0 -c abc -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Channel (-c) must be a positive integer"* ]]
}

@test "scan: -c without argument dies" {
    run bash "$WAI" scan -i wlan0 -c
    [ "$status" -ne 0 ]
    [[ "$output" == *"Option -c requires an argument"* ]]
}

@test "scan: unknown option dies" {
    run bash "$WAI" scan -i wlan0 -Z -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- cap ---

@test "cap: missing -i dies" {
    run bash "$WAI" cap -t TestNet -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required argument: -i"* ]]
}

@test "cap: missing -t dies" {
    run bash "$WAI" cap -i wlan0 -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required argument: -t"* ]]
}

# --- mon ---

@test "mon: missing action dies with usage" {
    run bash "$WAI" mon -i wlan0 -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: wai mon"* ]]
}

@test "mon: invalid action dies" {
    run bash "$WAI" mon -i wlan0 maybe -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid action"* ]]
}

# --- deth ---

@test "deth: invalid BSSID dies" {
    run bash "$WAI" deth -i wlan0 -t notamac -c 11:22:33:44:55:66 -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"valid BSSID"* ]]
}

@test "deth: invalid client MAC dies" {
    run bash "$WAI" deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c notamac -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"valid MAC"* ]]
}

@test "deth: missing -c dies" {
    run bash "$WAI" deth -i wlan0 -t AA:BB:CC:DD:EE:FF -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing -c"* ]]
}

@test "deth: two -t flags die (only one BSSID allowed)" {
    run bash "$WAI" deth -i wlan0 -t AA:BB:CC:DD:EE:FF -t AA:BB:CC:DD:EE:00 -c 11:22:33:44:55:66 -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"only one -t"* ]]
}

# --- opt ---

@test "opt: no files dies with usage" {
    run bash "$WAI" opt -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: wai opt"* ]]
}

@test "opt: nonexistent .cap dies with file-not-found" {
    run bash "$WAI" opt -o "$OUT" -n "$BATS_TEST_TMPDIR/missing.cap"
    [ "$status" -ne 0 ]
    [[ "$output" == *"File not found"* ]]
}
