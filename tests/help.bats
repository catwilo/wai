#!/usr/bin/env bats
# help.bats -- help index and per-subcommand help. No root, no hardware.
# The per-subcommand -h path is one branch of the dispatcher case: one
# representative (cap) plus the cleanup invariant cover it.

load helpers

setup() { setup_env; }

@test "wai -h: index with subcommands and routes, exit 0" {
    run bash "$WAI" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"SUBCOMMANDS"* ]]
    [[ "$output" == *"ROUTES"* ]]
    [[ "$output" == *"~/.local/share/wai"* ]]
    [[ "$output" == *"INTERNAL ACTIONS"* ]]
}

@test "wai cap -h: sub-help without root, lists tools and files" {
    run bash "$WAI" cap -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"wai v"* ]]
    [[ "$output" == *"cap"* ]]
    [[ "$output" == *"airodump-ng"* ]]
    [[ "$output" == *"wpaclean"* ]]
    [[ "$output" == *"~/.local/share/wai"* ]]
}

@test "wai cap -h: does not trigger the cleanup trap" {
    run bash "$WAI" cap -h
    [ "$status" -eq 0 ]
    [[ "$output" != *"Cleaning up"* ]]
    [[ "$output" != *"DRY-RUN"* ]]
}
