#!/usr/bin/env bats
# help.bats -- help index and per-subcommand help. No root, no hardware.

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

@test "wai cap -h: works without root, lists tools and files" {
    run bash "$WAI" cap -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"wai v"* ]]
    [[ "$output" == *"cap"* ]]
    [[ "$output" == *"airodump-ng"* ]]
    [[ "$output" == *"aireplay-ng"* ]]
    [[ "$output" == *"wpaclean"* ]]
    [[ "$output" == *"~/.local/share/wai"* ]]
}

@test "wai scan -h: works without root" {
    run bash "$WAI" scan -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"scan"* ]]
    [[ "$output" == *"airodump-ng"* ]]
    [[ "$output" == *"wifi monitor"* ]]
}

@test "wai mon -h: works without root" {
    run bash "$WAI" mon -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"mon"* ]]
    [[ "$output" == *"wifi monitor on"* ]]
    [[ "$output" == *"wifi monitor off"* ]]
}

@test "wai deth -h: works without root" {
    run bash "$WAI" deth -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"deth"* ]]
    [[ "$output" == *"aireplay-ng"* ]]
    [[ "$output" == *"BSSID"* ]]
}

@test "wai opt -h: works without root" {
    run bash "$WAI" opt -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"opt"* ]]
    [[ "$output" == *"wpaclean"* ]]
    [[ "$output" == *"hcxpcapngtool"* ]]
}

@test "wai cap -h: does not trigger the cleanup trap" {
    run bash "$WAI" cap -h
    [ "$status" -eq 0 ]
    [[ "$output" != *"Cleaning up"* ]]
    [[ "$output" != *"DRY-RUN"* ]]
}

@test "wai --help: alias for the index" {
    run bash "$WAI" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"cap"* ]]
    [[ "$output" == *"scan"* ]]
}
