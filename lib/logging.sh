#!/usr/bin/env bash
# lib/logging.sh -- Logging and color helpers.
# Not executed directly. Loaded by the entrypoint.
#
# Every function writes to stderr. This is CRITICAL: it lets callers use
# $(func) without the log messages contaminating the captured value.

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
N='\033[0m'
DIM='\033[2m'

ts()   { date '+%H:%M:%S'; }
info() { echo -e "${C}[.]${N} $(ts) $*" >&2; }
ok()   { echo -e "${G}[+]${N} $(ts) $*" >&2; }
warn() { echo -e "${Y}[!]${N} $(ts) $*" >&2; }
hdr()  { echo -e "\n${B}${C}-- $* --${N}" >&2; }
sep()  { echo -e "${DIM}$(printf -- '-%.0s' {1..76})${N}" >&2; }
die()  { echo -e "\n${R}[x] $(ts) $*${N}" >&2; exit 1; }
dbg()  { echo -e "${DIM}    [dbg] $(ts) $*${N}" >&2; }
