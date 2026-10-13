#!/usr/bin/env bats
# cli.bats -- top-level dispatch: version, help, unknown subcommand.

load helpers

setup() { setup_env; }

@test "wai -V prints version and exits 0" {
    run bash "$WAI" -V
    [ "$status" -eq 0 ]
    [[ "$output" == *"wai v"* ]]
}

@test "wai --help prints usage and exits 0" {
    run bash "$WAI" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"cap"* ]]
    [[ "$output" == *"scan"* ]]
}

@test "wai (no args) prints usage and exits 0" {
    run bash "$WAI"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "wai bogus: die with unknown subcommand" {
    run bash "$WAI" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown subcommand"* ]]
}
