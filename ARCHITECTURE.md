# wai -- Architecture

## Capas

    entrypoint (wai)  ->  subcomandos  ->  lib/*.sh  ->  binarios externos
                                                          + wifi-setup (red)

`wai` es un bash script unico que delega cada subcomando a `cmd_<name>`.
Cada `cmd_<name>` compone funciones de los modulos de `lib/`. Los modulos no
se llaman entre si fuera del orden declarado en el entrypoint.

## Principio de responsabilidades

wai es un CONSUMIDOR de la red. wifi-setup es el DUEÑO de la red.

- wai captura handshakes WPA2 (airodump-ng, aireplay-ng, aircrack-ng).
- wifi-setup gestiona las antenas, el modo managed/monitor y NetworkManager.
- wai NUNCA toca nmcli, ip link, systemctl, iwd, dhcpcd, wpa_supplicant
  ni iw directo. Todo cambio de estado de red se delega via `wifi`.

Esto mantiene wai agnostico al stack de red: si wifi-setup migra de NM a
otro gestor, wai no se entera.

## Subcomandos

    cap     preflight root -> install_trap -> monitor_up -> loop -> summary
    scan    preflight root -> install_trap -> monitor_up -> run_scan
    mon     preflight root -> install_trap -> monitor_up (on)
            preflight root -> install_trap -> monitor_down (off)
    deth    preflight root -> install_trap -> monitor_up -> aireplay-ng
    opt     preflight no_root -> install_trap -> loop optimize

`opt` es el unico subcomando que no toca la red: solo convierte archivos
.cap locales, por lo que preflight se invoca en modo `no_root`.

## Responsabilidad por archivo

### Raiz

    wai             Entrypoint. Carga modulos en orden, despacha a
                    `cmd_<sub>`. No contiene logica de captura.

    install.sh      Symlink a ~/.local/bin/wai. Nunca copia.

    README.md       Usuario: que hace, como se instala, como se usa,
                    flags comunes, dry-run, backend wifi-setup.

    ARCHITECTURE.md Este archivo. Mantenedor: responsabilidades, flujo,
                    decisiones no obvias.

    .gitignore      *.bak, *.part, *.log.

    .editorconfig   Estandar de formato del repo.

### lib/

    constants.sh    Version, tiempos, rutas, flags de herramientas
                    opcionales, TMP, WAI_DRY_RUN. Helpers `_sys` / `_sys_bg`
                    que respetan el dry-run.

    logging.sh      info/ok/warn/hdr/sep/die/dbg + colores ANSI. Todas
                    escriben a stderr. CRITICO: permite usar $(func) sin
                    que los mensajes contaminen el valor capturado.

    state.sh        Variables mutables (IFACE, TARGET, MON, ...) y
                    _reset_target_state para limpiar entre targets.

    cleanup.sh      cleanup() + install_trap(). install_trap se llama
                    desde cada cmd_<sub> DESPUES de preflight, nunca al
                    cargar el modulo: invocaciones que no tocan el
                    sistema (usage, -V, -h) no imprimen ruido al salir.
                    cleanup mata capturadores vivos y delega el regreso
                    a managed a `wifi monitor off` via monitor_down().

    args.sh         Un `parse_<sub>_args` por subcomando + `usage` +
                    `version` + `banner`. Valida formatos (BSSID, MAC,
                    canal) y crea OUTDIR. Unico lugar donde se leen flags.

    preflight.sh    preflight <root|no_root>. Dependencias obligatorias:
                    airodump-ng, aireplay-ng, aircrack-ng, wpaclean, wifi.
                    Detecta herramientas opcionales (hcxpcapngtool,
                    cap2hccapx, tshark) UNA sola vez y las guarda en HAS_*.

    meta.sh         Per-network metadata cache in
                    ${XDG_DATA_HOME:-~/.local/share}/wai/<slug>.meta
                    with a one-time migration from the legacy
                    ~/wssids path in init_meta().
                    TTL: META_MAX_AGE. Integrity checked on read.

    monitor.sh      monitor_up / monitor_down: UNICO punto de entrada a
                    control de modo monitor. Delegan a `wifi monitor
                    on/off <iface>`. Antes de delegar, corren
                    _monitor_safety_check: aborta si la iface lleva la
                    sesion SSH actual; aborta si no hay otra antena WiFi
                    con IP, salvo WAI_FORCE=1.

    scan.sh         run_scan (airodump-ng) y resolve_target (BSSID<->SSID,
                    canal). Bajo dry-run, resolve_target se resuelve sin
                    tocar la red.

    clients.sh      _scan_clients_fixed (airodump-ng con --bssid y
                    --channel fijos) + parseo CSV. detect_clients y
                    get_client_macs como interfaz publica.

    deauth.sh       _deauth_burst (todos los clientes en paralelo +
                    broadcast) y run_deauth (orquesta rondas). Devuelve
                    PID del subshell para que capture.sh lo mate.

    capture.sh      capture_once (airodump-ng -> deauth -> monitor de
                    handshake) y capture (reintentos + re-escaneo si
                    cache expirada). Verificacion con aircrack-ng y
                    tshark. Bajo dry-run, captura se simula.

    output.sh       optimize (wpaclean + conversion a .22000/.hccapx +
                    .info) y summary (resumen consolidado). Bajo dry-run,
                    optimize imprime las rutas que escribiria y no crea
                    archivos.

## Flujo de `cap`

    parse_cap_args -> banner
    -> preflight root
    -> install_trap
    -> monitor_up  (valida seguridad + delega a `wifi monitor on`)
    -> loop targets:
        _reset_target_state
        -> init_meta -> load_meta (o escaneo completo)
        -> resolve_target (BSSID, canal)
        -> capture:
            capture_once x MAX_TRIES_DEFAULT:
              detect_clients
              -> airodump-ng (background)
              -> run_deauth (background)
              -> _monitor_capture: salida inmediata al detectar handshake
        -> optimize (wpaclean + conversion)
    -> summary
    (EXIT trap: cleanup mata capturadores, monitor_down devuelve iface)

## Decisiones no obvias

### Por que wifi-setup es el dueño de la red y wai solo el consumidor

wai captura handshakes; no necesita saber si el gestor de red es NM, iwd
o networkd. Antes cada cambio de stack obligaba a tocar wai. Ahora wai
delega en `wifi monitor on/off`, que aplica el cambio con el stack
vigente. La regla es simple: si toca la red, va por `wifi`.

### Por que subcomandos y no solo flags

Cada fase es una operacion con valor propio: `scan` sin tocar la red,
`mon` para dejar la interfaz en monitor entre sesiones, `opt` para
convertir capturas ya existentes, `deth` para depurar un cliente
especifico.

### Por que todos los logs van a stderr

`clients.sh` usa `$(detect_clients)` para obtener un numero. Si `dbg`
escribiera a stdout, el valor capturado quedaria contaminado y bash
fallaria al comparar. Forzar stderr en logging.sh es la correccion que
hace posible la composicion funcional entre modulos.

### Por que dry-run existe desde el primer dia

La herramienta no se puede probar completa en Termux (no root, sin
interfaz fisica). Sin dry-run, cada cambio en el flujo requiere el
hardware real para saber si funciona. Con `-n` el mismo codigo se
recorre sin tocar el sistema, incluida la llamada a `wifi monitor`
(que en dry-run solo se imprime, no se ejecuta).

### Por que install_trap no se registra al cargar el modulo

Si el trap se registrara en el `source` de cleanup.sh, cualquier
invocacion (incluso `wai -h`) imprimiria "Cleaning up..." al salir.
Registrarlo desde cada cmd_<sub> despues de preflight lo mantiene
donde debe estar: solo cuando el subcomando toca el sistema.

### Por que los chequeos de seguridad antes de entrar en monitor

Poner una iface en monitor corta la conexion de esa iface. Si la
sesion SSH actual viaja por esa misma iface, el usuario pierde el
acceso. Si no hay otra antena con IP, no hay ruta alternativa.

    _monitor_safety_check <iface>:
      - iface lleva la sesion SSH (via SSH_CONNECTION) -> die (siempre).
      - no hay otra iface WiFi con IP -> die salvo WAI_FORCE=1.

Asi el error por defecto es seguro y explicito, y el usuario puede
forzar con WAI_FORCE=1 cuando tiene consola fisica.

### Por que el deauth es dirigido y no solo broadcast

Los APs modernos y los clientes con PMF (802.11w) filtran deauth
broadcast no autenticado. El deauth dirigido por MAC del cliente
fuerza reautenticacion individual y es la unica tecnica que funciona
contra stacks WPA2 modernos.

### Por que install.sh usa symlink y no copia

El entrypoint es un puntero vivo al repo. Un symlink hace que `git pull`
actualice el comando instalado automaticamente. Copiar obliga a
reinstalar en cada cambio y crea drift entre el binario instalado y el
source.

### Por que hay tests ahora

Los subcomandos de red requieren hardware Wi-Fi en modo monitor y
root, pero cuatro capas se ejercitan sin tocar la red:

    tests/cli.bats      dispatch, -V, -h, subcomando invalido.
    tests/args.bats     validacion de formato por subcomando
                        (BSSID, MAC, canal, faltantes, opciones
                        desconocidas). Corren antes de preflight.
    tests/dryrun.bats   flujo completo con -n: scan, cap (multiple
                        -t), deth; verifica que el launcher resuelve
                        el symlink y que dry-run no invoca wifi.
    tests/monitor.bats  comportamiento de los chequeos de seguridad:
                        iface lleva SSH -> die; sin otra wifi con IP ->
                        die salvo WAI_FORCE=1.

`bash tests/run.sh` imprime una linea por test con [N/total], el
archivo y el titulo. Sin \r, sin contadores in-place: un paste del
output es completo. Los fallos imprimen detalle indentado debajo.

Los subcomandos que tocan hardware real (mon on/off, captura real)
siguen verificandose en un host con root, interfaz Wi-Fi y red
autorizada; no son cubiertos por tests unitarios.
