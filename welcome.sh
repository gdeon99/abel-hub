#!/usr/bin/env bash
# ============================================================================
#  welcome.sh — panel sambutan ala datacenter, SEMUA elemen di-center.
#  Dipanggil otomatis dari /etc/bash.bashrc (sekali per sesi).
# ============================================================================

# lolcat di Debian ada di /usr/games — pastikan kebaca
export PATH="$PATH:/usr/games"

# ---- warna (ESC byte asli) ----
R=$'\e[1;31m'; G=$'\e[1;32m'; Y=$'\e[1;33m'; B=$'\e[1;34m'
M=$'\e[1;35m'; C=$'\e[1;36m'; W=$'\e[1;37m'; D=$'\e[0;90m'; N=$'\e[0m'

# ---- lebar terminal (fallback 80) ----
WIDTH=$( { tput cols 2>/dev/null || echo 80; } )
[ "${WIDTH:-0}" -gt 0 ] 2>/dev/null || WIDTH=80

# ---- helper ----
# buang kode warna ANSI biar ukur panjang teks akurat
_strip() { sed -E $'s/\e\\[[0-9;]*[a-zA-Z]//g'; }

# center: baca baris dari stdin, taruh di tengah berdasar lebar terminal
center() {
  local line vis pad
  while IFS= read -r line; do
    vis=$(printf '%s' "$line" | _strip)
    pad=$(( (WIDTH - ${#vis}) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s%s\n' "$pad" "" "$line"
  done
}

# garis pemisah, juga di-center
hr() {
  local w=$(( WIDTH > 64 ? 58 : WIDTH - 6 )); (( w < 10 )) && w=10
  local s; s=$(printf '─%.0s' $(seq 1 "$w"))
  printf '%s\n' "${D}${s}${N}" | center
}

# ---- kumpulkan info mesin ----
HOSTN=$(hostname 2>/dev/null)
OSN=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}")
KERN=$(uname -r)
ARCHN=$(uname -m)
UPT=$(uptime -p 2>/dev/null | sed 's/^up //'); [ -z "$UPT" ] && UPT="-"
CPUN=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
[ -z "$CPUN" ] && CPUN="$(uname -p)"
CORES=$(nproc 2>/dev/null)
MEMN=$(free -h 2>/dev/null | awk '/^Mem:/{print $3" / "$2}')
DISKN=$(df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')
LOADN=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
IPN=$(hostname -I 2>/dev/null | awk '{print $1}'); [ -z "$IPN" ] && IPN="-"
NOW=$(date '+%Y-%m-%d  %H:%M:%S  %Z')

# ---- render panel ----
echo
if command -v figlet >/dev/null 2>&1; then
  if command -v lolcat >/dev/null 2>&1; then
    figlet -f slant "ABEL LABS" | lolcat -f | center
  else
    figlet -f slant "ABEL LABS" | center
  fi
else
  printf '%s\n' "${C}A B E L   L A B S${N}" | center
fi
echo
printf '%s\n' "${G}●${N} ${W}NODE ONLINE${N}   ${D}·${N}   ${C}HUB SHELL${N}   ${D}·${N}   ${Y}${NOW}${N}" | center
hr
printf '%s\n' "${C}Host${N}  ${W}${HOSTN}${N}     ${C}IP${N}  ${W}${IPN}${N}" | center
printf '%s\n' "${C}OS${N}  ${W}${OSN}${N} ${D}(${ARCHN})${N}" | center
printf '%s\n' "${C}Kernel${N}  ${W}${KERN}${N}" | center
printf '%s\n' "${C}CPU${N}  ${W}${CPUN}${N} ${D}(${CORES} cores)${N}" | center
printf '%s\n' "${C}Memory${N}  ${W}${MEMN}${N}     ${C}Disk${N}  ${W}${DISKN}${N}" | center
printf '%s\n' "${C}Uptime${N}  ${W}${UPT}${N}     ${C}Load${N}  ${W}${LOADN}${N}" | center
hr
printf '%s\n' "${D}ketik${N} ${C}exit${N} ${D}keluar${N}   ${D}·${N}   ${D}ketik${N} ${C}neofetch${N} ${D}buat detail lengkap${N}" | center
echo
