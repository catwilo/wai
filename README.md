# wai -- WPA2 Handshake Capture CLI

SOLO PARA REDES PROPIAS O AUTORIZADAS -- USO EDUCATIVO / LAB

CLI para capturar handshakes WPA2 en redes propias. Orquesta cinco
subcomandos sobre un conjunto de modulos en `lib/`.

---

## Instalacion

    ./install.sh

Crea un symlink en `~/.local/bin/wai`. Requiere root para ejecutar.

## Uso

    sudo wai <subcomando> [flags]

| Subcomando | Descripcion |
|---|---|
| `cap`  | Flujo completo: scan -> monitor -> deauth -> captura -> optimizar |
| `scan` | Solo escanear y listar redes visibles |
| `mon`  | Activar/desactivar modo monitor: `wai mon -i <iface> on\|off` |
| `deth` | Deauth dirigido a un cliente especifico (depuracion en lab) |
| `opt`  | Convertir `.cap` existentes a `.22000`/`.hccapx` |

### Flags comunes

| Flag | Descripcion | Subcomandos |
|---|---|---|
| `-i` | Interfaz fisica (ej: `wlan0`) | cap, scan, mon, deth |
| `-t` | BSSID (`AA:BB:...`) o SSID (repetible en `cap`) | cap, deth |
| `-c` | Canal (cap/scan) - MAC del cliente (deth) | cap, scan, deth |
| `-o` | Directorio de salida (default: `pwd`) | cap, opt |
| `-h` | Ayuda | todos |

### Ejemplos

    sudo wai cap -i wlan0 -t "MiRed" -t AA:BB:CC:DD:EE:FF
    sudo wai scan -i wlan0
    sudo wai mon -i wlan0 on
    sudo wai deth -i wlan0 -t AA:BB:CC:DD:EE:FF -c 11:22:33:44:55:66
    sudo wai opt -o /tmp/caps capture1.cap capture2.cap

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
    |-- ARCHITECTURE.md      # responsabilidades por modulo, flujo, decisiones
    `-- lib/
        |-- constants.sh     # tiempos, rutas, version
        |-- logging.sh       # info/ok/warn/die/dbg -- todos a stderr
        |-- state.sh         # variables mutables
        |-- cleanup.sh       # trap EXIT/INT: restaurar interfaz e iwd
        |-- args.sh          # parseo por subcomando
        |-- preflight.sh     # root + dependencias
        |-- meta.sh          # cache de metadatos por red (~/.wssids/)
        |-- iwd.sh           # detener/restaurar iwd
        |-- monitor.sh       # modo monitor (airmon-ng + fallback iw)
        |-- scan.sh          # escaneo y resolucion de BSSID/canal
        |-- clients.sh       # deteccion de clientes del AP
        |-- deauth.sh        # deauth dirigido + broadcast
        |-- capture.sh       # captura del handshake y verificacion
        `-- output.sh        # wpaclean, conversion y resumen

## Licencia

Sin licencia. Repositorio privado. Uso educativo / lab unicamente.
