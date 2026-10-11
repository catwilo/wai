#!/usr/bin/env bats
# dryrun.bats -- complete dry-run flows. No hardware, no root.
# Asserts the README claim: dry-run exercises the whole CLI without
# touching the network stack.

load helpers

setup() { setup_env; }

@test "scan dry-run completes with rc=0" {
    run bash "$WAI" scan -i wlan0 -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"Scan finished"* ]]
    [[ "$output" == *"Finished OK"* ]]
}

@test "cap dry-run completes with rc=0 and reports each target" {
    run bash "$WAI" cap -i wlan0 -t TestNet -o "$OUT" -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"TARGET 1/1: TestNet"* ]]
    [[ "$output" == *"Finished OK"* ]]
}

@test "cap dry-run with multiple -t processes each target in order" {
    run bash "$WAI" cap -i wlan0 -t Alpha -t Beta -t Gamma -o "$OUT" -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"TARGET 1/3: Alpha"* ]]
    [[ "$output" == *"TARGET 2/3: Beta"* ]]
    [[ "$output" == *"TARGET 3/3: Gamma"* ]]
}

@test "deth dry-run completes with rc=0" {
    run bash "$WAI" deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66 -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] aireplay-ng"* ]]
    [[ "$output" == *"Finished OK"* ]]
}

@test "dry-run no invoca wifi-setup (backend) para monitor" {
    # dry-run debe imprimir la accion sin llamar a wifi. Un binario
    # wifi falso en PATH que falla si es invocado, verifica esto.
    local fakebin="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$fakebin"
    cat > "$fakebin/wifi" <<'FAKE'
#!/usr/bin/env bash
echo "FAKE wifi llamado en dry-run" >&2
exit 99
FAKE
    chmod +x "$fakebin/wifi"

    PATH="$fakebin:$PATH" run bash "$WAI" cap -i wlan0 -t CleanState -o "$OUT" -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] wifi monitor on wlan0"* ]]
    [[ "$output" != *"FAKE wifi llamado"* ]]
}

@test "launcher resolves symlink: invoking via a symlink works" {
    ln -sf "$WAI" "$BATS_TEST_TMPDIR/wai-link"
    run bash "$BATS_TEST_TMPDIR/wai-link" -V
    [ "$status" -eq 0 ]
    [[ "$output" == *"wai v"* ]]
}
