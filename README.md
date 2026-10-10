# wai -- WPA2 Handshake Capture CLI

SOLO PARA REDES PROPIAS O AUTORIZADAS -- USO EDUCATIVO / LAB

CLI para capturar handshakes WPA2 en redes propias. Orquesta cinco
subcomandos sobre un conjunto de modulos en `lib/`.

---

## Instalacion

    ./install.sh

Crea un symlink en `~/.local/bin/wai`. Requiere root para ejecutar
(excepto `opt`, que solo lee archivos .cap locales).

## Uso

    sudo wai <subcomando> [flags]

| Subcomando | Descripcion |
|---|---|
| `cap`  | Flujo completo: scan -> monitor -> deauth -> captura -> optimizar |
| `scan` | Solo escanear y listar redes visibles |
| `mon`  | Activar/desactivar modo monitor: `wai mon -i <iface> on\|off` |
| `deth` | Deauth dirigido a un cliente especifico (depuracion en lab) |
| `opt`  | Convertir `.cap` existentes a `.22000`/`.hccapx` (no requiere root) |

### Flags comunes

| Flag | Descripcion | Subcomandos |
|---|---|---|
| `-i` | Interfaz fisica (ej: `wlan0`) | cap, scan, mon, deth |
| `-t` | BSSID (`AA:BB:...`) o SSID (repetible en `cap`) | cap, deth |
| `-c` | Canal (cap/scan) - MAC del cliente (deth) | cap, scan, deth |
| `-o` | Directorio de salida (default: `pwd`) | cap, opt |
| `-n` | Dry-run: imprime acciones, no toca el sistema | todos |
| `-V` | Version | todos |
| `-h` | Ayuda | todos |

### Ejemplos

    sudo wai cap -i wlan0 -t "MiRed" -t AA:BB:CC:DD:EE:FF
    sudo wai cap -i wlan0 -t "MiRed" --dry-run     # no toca el sistema
    sudo wai scan -i wlan0
    sudo wai mon -i wlan0 on
    sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66
    sudo wai opt -o ~/caps capture1.cap capture2.cap

### Dry-run

`-n` (o `WAI_DRY_RUN=1` en el entorno) recorre todo el flujo sin ejecutar
nada contra el hardware ni el sistema de archivos. Verifica:

- Que los argumentos se parsean y validan correctamente.
- Que la secuencia de pasos por subcomando es la esperada.
- Que los archivos que se escribirian, se reportan sin escribirlos.

Se puede correr sin root; permite probar el CLI desde cualquier host.

## Dependencias

Obligatorias:

    sudo apt install aircrack-ng iwd

Opcionales (mejoran la salida):

    sudo apt install tshark      # Analisis EAPOL preciso
    sudo apt install hcxtools    # Convierte a formato .22000 (hashcat moderno)

## Estructura

    wai/
    |-- wai                  # entrypoint (dispatch de subcomandos)
    |-- install.sh           # symlink a ~/.local/bin/wai
    |-- README.md            # este archivo
    |-- ARCHITECTURE.md      # responsabilidades, flujo, decisiones
    `-- lib/
        |-- constants.sh     # tiempos, rutas, version, WAI_DRY_RUN
        |-- logging.sh       # info/ok/warn/die/dbg -- todos a stderr
        |-- state.sh         # variables mutables + estado por target
        |-- cleanup.sh       # trap EXIT/INT: restaurar iwd y monitor
        |-- args.sh          # parseo por subcomando
        |-- preflight.sh     # root (opcional) + dependencias
        |-- meta.sh          # cache de metadatos por red (XDG data dir)
        |-- iwd.sh           # detener/restaurar iwd (con estado entre procesos)
        |-- monitor.sh       # monitor_up/monitor_down (unico punto de entrada)
        |-- scan.sh          # escaneo y resolucion de BSSID/canal
        |-- clients.sh       # deteccion de clientes del AP
        |-- deauth.sh        # deauth dirigido + broadcast
        |-- capture.sh       # captura del handshake y verificacion
        |-- output.sh        # wpaclean, conversion y resumen
    `-- tests/               # suite BATS -- bash tests/run.sh
        |-- helpers.bash     # setup aislado por test (HOME/XDG/TMPDIR)
        |-- cli.bats         # dispatch: -V, -h, subcomando desconocido
        |-- args.bats        # validacion de formato por subcomando
        |-- dryrun.bats      # flujo completo con -n
        `-- run.sh           # runner: una linea por test

## Tests

    bash tests/run.sh

Corre la suite BATS. Una linea por test con `[N/total] PASS|FAIL`,
nombre del archivo y titulo. Un paste del output es completo y
ordenado. Cero dependencia de hardware: todo lo que la suite ejercita
corre sin root y sin interfaz Wi-Fi.

Cobertura actual:

    cli.bats      dispatch: -V, --help, subcomando desconocido.
    args.bats     validacion de formato por subcomando (BSSID, MAC,
                  canal, faltantes).
    dryrun.bats   flujo completo con -n: scan, cap (-t multiple),
                  deth, y limpieza de WAI_STATE_FILE.

## Licencia

Sin licencia. Repositorio privado. Uso educativo / lab unicamente.
