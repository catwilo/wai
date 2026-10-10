# wai -- Architecture

## Capas

    entrypoint (wai)  ->  subcomandos  ->  lib/*.sh  ->  binarios externos

`wai` es un bash script unico que delega cada subcomando a `cmd_<name>`.
Cada `cmd_<name>` compone funciones de los modulos de `lib/`. Los modulos no
se llaman entre si fuera del orden declarado en el entrypoint.

## Subcomandos

    cap     Composicion: preflight -> iwd -> monitor -> (loop) -> summary
    scan    preflight -> iwd -> monitor -> run_scan -> cleanup
    mon     preflight -> iwd -> monitor (on)  |  airmon stop + cleanup (off)
    deth    preflight -> iwd -> monitor -> aireplay-ng -> cleanup
    opt     (sin monitor) -> optimize sobre archivos .cap ya existentes

Todos comparten preflight (root + dependencias) salvo `opt`, que no toca
la interfaz. Todos registran la salida final via `summary` cuando producen
archivos.

## Responsabilidad por archivo

### Raiz

    wai             Entrypoint. Forza bash, carga modulos en orden, despacha
                    a `cmd_<sub>`. Nunca contiene logica de captura.

    install.sh      Symlink a ~/.local/bin/wai. Nunca copia.

    README.md       Usuario: que hace, como se instala, como se usa.

    ARCHITECTURE.md Este archivo. Mantenedor: responsabilidades, flujo,
                    decisiones no obvias.

    .gitignore      *.bak, *.part, *.log.

    .editorconfig   Estandar de formato del repo.

### lib/

    constants.sh    Version, tiempos (SCAN_SEC, CAP_MAX_SEC, DEAUTH_N),
                    rutas, flags de herramientas opcionales, TMP.
                    Ninguna funcion; solo constantes y variables globales.

    logging.sh      info/ok/warn/hdr/sep/die/dbg + colores ANSI.
                    CRITICO: todas escriben a stderr. Esto permite usar
                    $(func) sin que los mensajes contaminen el valor.

    state.sh        Variables mutables (IFACE, TARGET, MON, ...) y
                    _reset_target_state para limpiar entre targets.

    cleanup.sh      cleanup() + trap EXIT/INT. Restaura iwd, detiene
                    monitor, borra TMP. Registrado una sola vez.

    args.sh         Un `parse_<sub>_args` por subcomando + `usage` +
                    `banner`. Valida rangos y formatos (BSSID, MAC, canal).
                    Es el UNICO lugar donde se leen flags.

    preflight.sh    Verifica root, dependencias obligatorias, detecta
                    opcionales (HAS_HCXPCAPNGTOOL, HAS_CAP2HCCAPX,
                    HAS_TSHARK). Ninguna otra funcion vuelve a hacer
                    `command -v`.

    meta.sh         Cache de metadatos por red en ~/.wssids/<slug>.meta
                    con TTL (META_MAX_AGE). Valida integridad al leer.

    iwd.sh          save_and_stop_iwd: guarda la red conectada, detiene
                    iwd, la enmascara. Reverso en cleanup.sh.

    monitor.sh      start_monitor: mata dhcpcd/wpa_supplicant, `airmon-ng
                    start`, resuelve el nombre de la interfaz monitor
                    (fallback: iw dev).

    scan.sh         run_scan (airodump-ng) y resolve_target (BSSID<->SSID,
                    canal). Escribe CSV y .meta.

    clients.sh      _scan_clients_fixed (airodump-ng con --bssid y
                    --channel fijos) + parseo CSV. detect_clients y
                    get_client_macs como interfaz publica.

    deauth.sh       _deauth_burst (todos los clientes en paralelo +
                    broadcast) y run_deauth (orquesta rondas). Devuelve
                    PID del subshell para que capture.sh lo mate.

    capture.sh      capture_once (airodump-ng -> deauth -> monitor de
                    handshake) y capture (reintentos + re-escaneo si
                    cache expirada). Verificacion con aircrack-ng y
                    tshark.

    output.sh       optimize (wpaclean + conversion a .22000/.hccapx +
                    .info) y summary (resumen consolidado por target).

## Flujo de `cap`

    parse_cap_args -> banner
    -> preflight (root + deps)
    -> save_and_stop_iwd
    -> start_monitor
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
    -> summary (registrado por EXIT trap: cleanup)

## Decisiones no obvias

### Por que subcomandos y no solo flags

`wlab` era un unico flujo monolitico. `wai` expone cada fase como subcomando
porque son operaciones independientes con valor propio: `scan` sin tocar
iwd, `mon` para dejar la interfaz en modo monitor entre sesiones, `opt`
para convertir capturas ya existentes, `deth` para depurar un cliente
especifico. Los subcomandos no comparten estado mas alla de `lib/`.

### Por que todos los logs van a stderr

`clients.sh` usa `$(detect_clients)` para obtener un numero. Si `dbg`
escribiera a stdout, el valor capturado quedaria contaminado y bash
fallaria al comparar. Forzar stderr en logging.sh es la correccion que
hace posible la composicion funcional entre modulos.

### Por que el deauth es dirigido y no solo broadcast

Los APs modernos y los clientes con PMF (802.11w) filtran deauth broadcast
no autenticado. El deauth dirigido por MAC del cliente fuerza
reautenticacion individual y es la unica tecnica que funciona contra
stacks WPA2 modernos.

### Por que `install.sh` usa symlink y no copia

El entrypoint es un puntero vivo al repo. Un symlink hace que `git pull`
actualice el comando instalado automaticamente. Copiar obliga a reinstalar
en cada cambio y crea drift entre el binario instalado y el source.

### Por que no hay tests todavia

Cada subcomando requiere hardware Wi-Fi en modo monitor y privilegios
root. Los tests unitarios que valdria la pena cubririan `args.sh`
(validacion de formato) y `meta.sh` (sanitizacion de nombres); se anaden
cuando se estabilicen sus firmas.
