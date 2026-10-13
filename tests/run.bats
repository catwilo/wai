#!/usr/bin/env bats
# run.bats -- contract of 'wai run'. No root, no hardware.

load helpers

setup() { setup_env; }

@test "run: recorre el scope en orden (dry-run)" {
    bash "$WAI" scope add Alpha
    bash "$WAI" scope add Beta
    run bash "$WAI" run -i wlan0 -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"TARGET 1/2: Alpha"* ]]
    [[ "$output" == *"TARGET 2/2: Beta"* ]]
}

@test "run: -o redirige las capturas al directorio dado" {
    bash "$WAI" scope add Alpha
    local out="$BATS_TEST_TMPDIR/mycaps"
    run bash "$WAI" run -i wlan0 -o "$out" -n
    [ "$status" -eq 0 ]
    [[ -d "$out" ]]
}

@test "run: sin -i muere con mensaje claro" {
    run bash "$WAI" run -n
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required argument: -i"* ]]
}
