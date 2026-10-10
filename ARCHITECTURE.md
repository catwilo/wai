# wai -- Architecture

## Capas

    entrypoint (wai)  ->  subcomandos  ->  lib/*.sh  ->  binarios externos

`wai` es un bash script unico que delega cada subcomando a `cmd_<name>`.
Cada `cmd_<name>` compone funciones de los modulos de `lib/`. Los modulos no
se llaman entre si fuera del orden declarado en el entrypoint.

## Subcomandos

    cap     preflight root -> install_trap -> iwd -> monitor_up -> loop -> summary
    scan    preflight root -> install_trap -> iwd -> monitor_up -> run_scan
    mon     preflight root -> install_trap -> iwd -> monitor_up (on)
            preflight root -> install_trap -> monitor_down (off)
    deth    preflight root -> install_trap -> iwd -> monitor_up -> aireplay-ng
    opt     preflight no_root -> install_trap -> loop optimize

`opt` es el unico subcomando que no toca la red: solo convierte archivos
.cap locales, por lo que preflight se invoca en modo `no_root`.

## Responsabilidad por archivo

### Raiz

    wai             Entrypoint. Carga modulos en orden, despacha a
                    `cmd_<sub>`. No contiene logica de captura.

    install.sh      Symlink a ~/.local/bin/wai. Nunca copia.

    README.md       Usuario: que hace, como se instala, como se usa,
                    flags comunes, dry-run.

    ARCHITECTURE.md Este archivo. Mantenedor: responsabilidades, flujo,
                    decisiones no obvias.

    .gitignore      *.bak, *.part, *.log.

    .editorconfig   Estandar de formato del repo.

### lib/

    constants.sh    Version, tiempos, rutas, flags de herramientas
                    opcionales, TMP, WAI_STATE_FILE, WAI_DRY_RUN. Helpers
                    `_sys` / `_sys_bg` que respetan el dry-run.

    logging.sh      info/ok/warn/hdr/sep/die/dbg + colores ANSI. Todas
                    escriben a stderr. CRITICO: permite usar $(func) sin
                    que los mensajes contaminen el valor capturado.

    state.sh        Variables mutables (IFACE, TARGET, MON, ...) y
                    _reset_target_state para limpiar entre targets.

    cleanup.sh      cleanup() + install_trap(). install_trap se llama
                    desde cada cmd_<sub> DESPUES de preflight, nunca al
                    cargar el modulo: invocaciones que no tocan el
                    sistema (usage, -V, -h) no imprimen ruido al salir.
                    cleanup lee WAI_STATE_FILE para restaurar iwd cuando
                    el estado fue creado por otra invocacion.

    args.sh         Un `parse_<sub>_args` por subcomando + `usage` +
                    `version` + `banner`. Valida formatos (BSSID, MAC,
                    canal) y crea OUTDIR. Unico lugar donde se leen flags.

    preflight.sh    preflight <root|no_root>. Detecta herramientas
                    opcionales (hcxpcapngtool, cap2hccapx, tshark) UNA
                    sola vez y las guarda en HAS_*. Ninguna otra funcion
                    vuelve a llamar `command -v`.

    meta.sh         Per-network metadata cache in
                    ${XDG_DATA_HOME:-~/.local/share}/wai/<slug>.meta
                    with a one-time migration from the legacy
                    ~/wssids path in init_meta().
                    TTL: META_MAX_AGE. Integrity checked on read.

    iwd.sh          save_and_stop_iwd: guarda la red conectada, detiene
                    iwd, la enmascara, y persiste el estado en
                    WAI_STATE_FILE. El cleanup lo restaura.

    monitor.sh      monitor_up / monitor_down: UNICO punto de entrada a
                    control de modo monitor. Cada subcomando que necesita
                    monitor llama monitor_up; `wai mon off` y cleanup
                    llaman monitor_down.

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
    -> save_and_stop_iwd
    -> monitor_up
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
    (EXIT trap: cleanup restaura iwd y detiene monitor)

## Decisiones no obvias

### Por que subcomandos y no solo flags

Cada fase es una operacion con valor propio: `scan` sin tocar iwd,
`mon` para dejar la interfaz en modo monitor entre sesiones, `opt`
para convertir capturas ya existentes, `deth` para depurar un cliente
especifico.

### Por que todos los logs van a stderr

`clients.sh` usa `$(detect_clients)` para obtener un numero. Si `dbg`
escribiera a stdout, el valor capturado quedaria contaminado y bash
fallaria al comparar. Forzar stderr en logging.sh es la correccion que
hace posible la composicion funcional entre modulos.

### Por que dry-run existe desde el primer dia

La herramienta no se puede probar completa en Termux (no root, sin
airmon-ng, sin interfaz fisica). Sin dry-run, cada cambio en el flujo
requiere el hardware real para saber si funciona. Con `-n` el mismo
codigo se recorre sin tocar el sistema.

### Por que install_trap no se registra al cargar el modulo

Si el trap se registrara en el `source` de cleanup.sh, cualquier
invocacion (incluso `wai -h`) imprimiria "Cleaning up..." al salir.
Registrarlo desde cada cmd_<sub> despues de preflight lo mantiene
donde debe estar: solo cuando el subcomando toca el sistema.

### Por que el estado de iwd viaja entre procesos

`wai mon on` y `wai mon off` son invocaciones distintas. Si `mon on`
detiene iwd y enmascara el servicio, `mon off` debe poder desenmascarar
aunque sea un proceso nuevo. WAI_STATE_FILE persiste IWD_WAS_UP,
IWD_NET e IFACE entre las dos invocaciones.

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

### Por que no hay tests todavia

Los subcomandos de red requieren hardware Wi-Fi en modo monitor y root.
Los tests unitarios que valdria la pena cubririan `args.sh` (validacion
de formato) y `meta.sh` (sanitizacion de nombres); se anaden cuando sus
firmas se estabilicen.
