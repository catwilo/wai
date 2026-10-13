# wai -- WPA2 Handshake Capture CLI

SOLO PARA REDES PROPIAS O AUTORIZADAS -- USO EDUCATIVO / LAB

CLI para capturar handshakes WPA2 en redes propias. Orquesta siete
subcomandos sobre un conjunto de modulos en `lib/`. Las capturas se
guardan fuera del repo (`~/.wai/`); nada se versiona.

**Backend de red: wifi-setup.** wai no toca NetworkManager, iwd ni
dhcpcd. El modo monitor se delega a `wifi monitor on/off <iface>`, que
es la herramienta que controla las antenas. Instala wifi-setup primero:
`ut distribute --install wifi-setup`.

---

## Instalacion

    ./install.sh

Crea un symlink en `~/.local/bin/wai`. Requiere root para ejecutar
(excepto `opt` y `scope`, que no tocan la red).

## Uso

    sudo wai <subcomando> [flags]

| Subcomando | Descripcion |
|---|---|
| `cap`   | Flujo completo: scan -> monitor -> deauth -> captura -> optimizar |
| `scan`  | Solo escanear y listar redes visibles |
| `mon`   | Activar/desactivar modo monitor: `wai mon -i <iface> on\|off` |
| `deth`  | Deauth dirigido a un cliente especifico (depuracion en lab) |
| `opt`   | Convertir `.cap` existentes a `.22000`/`.hccapx` (no requiere root) |
| `scope` | Editar la lista de redes autorizadas en `~/.wai/scope` |
| `run`   | Capturar cada red del scope, guardando en `~/.wai/captures/` |

### Flags comunes

| Flag | Descripcion | Subcomandos |
|---|---|---|
| `-i` | Interfaz fisica (ej: `wlan0`) | cap, scan, mon, deth, run |
| `-t` | BSSID (`AA:BB:...`) o SSID (repetible en `cap`) | cap, deth |
| `-c` | Canal (cap/scan) - MAC del cliente (deth) | cap, scan, deth |
| `-o` | Directorio de salida (default: `pwd` o `~/.wai/captures/`) | cap, opt, run |
| `-n` | Dry-run: imprime acciones, no toca el sistema | todos |
| `-V` | Version | todos |
| `-h` | Ayuda | todos |

### Ejemplos

    sudo wai cap -i wlan0 -t "MiRed" -t AA:BB:CC:DD:EE:FF
    sudo wai cap -i wlan0 -t "MiRed" -n            # no toca el sistema
    sudo wai scan -i wlan0
    sudo wai mon -i wlan0 on
    sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66
    sudo wai opt -o ~/caps capture1.cap capture2.cap

    # Flujo por lote: la lista vive en ~/.wai/scope
    wai scope add "MiRed"
    wai scope add AA:BB:CC:DD:EE:FF
    wai scope edit                       # revisar antes de capturar
    sudo wai run -i wlan0                # captura todo el scope en orden

### Elegir la antena

Si el equipo tiene dos antenas WiFi, elegi como `-i` la que vas a usar
para captura. La otra antena mantiene la conexion (y tu sesion SSH).
wai aborta automaticamente si:

- La iface elegida lleva la sesion SSH actual.
- No hay otra antena WiFi con IP (a menos que pases `WAI_FORCE=1`).

Revisa el inventario con `wifi ifaces`.

### Scope y capturas por lote

El archivo `~/.wai/scope` (modo 600) es una lista de texto plano de las
redes que autorizas: una por linea, SSID o BSSID. Lineas que empiezan
con `#` son comentarios. `wai scan` **nunca** escribe ahi -- vos
promoves cada entrada a mano, para que ninguna red se capture sin una
decision explicita.

    wai scope           # ver path + entradas
    wai scope add <X>   # agregar
    wai scope rm  <X>   # quitar
    wai scope edit      # abrir $EDITOR
    wai scope clear     # vaciar (pide confirmacion)

`wai run -i <iface>` recorre el scope y corre el flujo `cap` completo
por cada entrada, guardando los archivos en
`~/.wai/captures/run-<YYYYMMDD-HHMMSS>/` (override con `-o <dir>`).
Un solo `summary` consolidado al final.

Nada de lo que vive en `~/.wai/` se versiona: es material de laboratorio.

### Dry-run

`-n` (o `WAI_DRY_RUN=1` en el entorno) recorre todo el flujo sin ejecutar
nada contra el hardware ni el sistema de archivos. Verifica:

- Que los argumentos se parsean y validan correctamente.
- Que la secuencia de pasos por subcomando es la esperada.
- Que los archivos que se escribirian se reportan sin escribirlos.
- Que la llamada a `wifi monitor on/off` se imprime sin ejecutar.

Se puede correr sin root; permite probar el CLI desde cualquier host.

## Dependencias

Obligatorias:

    sudo apt install aircrack-ng       # airodump-ng, aireplay-ng, aircrack-ng, wpaclean
    ut distribute --install wifi-setup # backend de red (NetworkManager)

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
        |-- help.sh          # help_index + help_<sub> (colores, rutas, acciones)
        |-- state.sh         # variables mutables + estado por target
        |-- cleanup.sh       # trap EXIT/INT: matar capturadores + managed
        |-- args.sh          # parseo por subcomando
        |-- preflight.sh     # root (opcional) + dependencias
        |-- meta.sh          # cache de metadatos por red (XDG data dir)
        |-- scope.sh         # ~/.wai/scope + CAPTURES_DIR (list + paths)
        |-- monitor.sh       # monitor_up/monitor_down: delegan a wifi-setup
        |-- scan.sh          # escaneo y resolucion de BSSID/canal
        |-- clients.sh       # deteccion de clientes del AP
        |-- deauth.sh        # deauth dirigido + broadcast
        |-- capture.sh       # captura del handshake y verificacion
        `-- output.sh        # wpaclean, conversion y resumen

## Tests

    bash tests/run.sh

Corre la suite BATS. Una linea por test con `[N/total] PASS|FAIL`,
nombre del archivo y titulo. Un paste del output es completo y
ordenado. Cero dependencia de hardware: todo lo que la suite ejercita
corre sin root y sin interfaz Wi-Fi.

Cobertura actual:

    cli.bats      dispatch: -V, --help, sin args, subcomando invalido.
    help.bats     indice + `-h` de un subcomando; invariante: `-h` no
                  dispara el trap de cleanup.
    args.bats     validacion de formato por subcomando (BSSID, MAC,
                  canal, faltantes).
    dryrun.bats   flujo completo con -n: scan, cap (-t multiple),
                  deth, y la no-invocacion de wifi en dry-run.
    monitor.bats  chequeos de seguridad: iface lleva SSH -> die;
                  sin otra wifi con IP -> die salvo WAI_FORCE=1.
    scope.bats    dedupe, rechazo de `#`, comentarios/vacias, permiso 600.
    run.bats      orden del scope, `-o` redirige, `-i` obligatorio.

## Licencia

Sin licencia. Repositorio privado. Uso educativo / lab unicamente.
