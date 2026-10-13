#!/usr/bin/env bats
# scope.bats -- contract of ~/.wai/scope. No root, no hardware.

load helpers

setup() { setup_env; }

@test "scope add: idempotente (no duplica la misma entrada)" {
    bash "$WAI" scope add LabNet
    bash "$WAI" scope add LabNet
    local count
    count=$(bash "$WAI" scope 2>/dev/null | grep -c '^  *[0-9]*) LabNet$')
    [ "$count" -eq 1 ]
}

@test "scope add: rechaza entradas que empiezan con #" {
    run bash "$WAI" scope add "# comentario"
    [ "$status" -ne 0 ]
    [[ "$output" == *"reservado para comentarios"* ]]
}

@test "scope read: ignora comentarios y lineas vacias" {
    mkdir -p "$HOME/.wai"
    printf '# comentario\n\nLabNet\n\n  # otro\n' > "$HOME/.wai/scope"
    chmod 600 "$HOME/.wai/scope"
    local count
    count=$(bash "$WAI" scope 2>/dev/null | grep -c '^  *[0-9]*) ')
    [ "$count" -eq 1 ]
}

@test "scope file: permiso 600 tras agregar la primera entrada" {
    bash "$WAI" scope add LabNet
    local mode
    mode=$(stat -c '%a' "$HOME/.wai/scope" 2>/dev/null || stat -f '%A' "$HOME/.wai/scope")
    [ "$mode" = "600" ]
}
