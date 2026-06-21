#!/usr/bin/env bash
# ============================================================================
#  connect.sh — colok mesin ke hub. 1x jalan, auto-deteksi port, anti-error.
#  - cari sendiri port kosong di hub (7001=Mesin1, 7002=Mesin2, ...)
#  - idempotent: di-jalanin ulang aman (bersihin yg lama dulu)
#  - retry download, self-heal (restart sendiri kalau putus)
#  - pasang sshd + tmux auto (session gak mati walau koneksi putus)
#  Override buat tes: ABEL_SERVER / ABEL_HUBPORT / ABEL_TOKEN
# ============================================================================
set -u

# Token frp WAJIB (argumen ke-1 atau env ABEL_TOKEN). Server/port punya default.
TOKEN="${1:-${ABEL_TOKEN:-}}"
SERVER="${2:-${ABEL_SERVER:-shortline.proxy.rlwy.net}}"
HUBPORT="${3:-${ABEL_HUBPORT:-31913}}"
if [ -z "$TOKEN" ]; then
  echo "Pakai: curl -fsSL <url>/connect.sh | bash -s -- <FRP_TOKEN> [server] [port]"
  exit 1
fi
FRP_VER="0.69.1"
PORT_MIN=7001
PORT_MAX=7010
SSHPORT="${SSH_LOCAL_PORT:-22}"

C=$'\033[1;36m'; Y=$'\033[1;33m'; G=$'\033[1;32m'; N=$'\033[0m'
log(){  echo "${C}[abel]${N} $*"; }
warn(){ echo "${Y}[abel]${N} $*"; }

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# --- 0) arsitektur ---
case "$(uname -m)" in
  x86_64|amd64)        ARCH=amd64 ;;
  aarch64|arm64)       ARCH=arm64 ;;
  armv7l|armv8l|armhf) ARCH=arm ;;
  *) warn "arsitektur $(uname -m) gak didukung"; exit 1 ;;
esac

# --- 1) dependency (curl/tar/openssh/tmux) ---
need=0
command -v curl >/dev/null 2>&1 || need=1
command -v tar  >/dev/null 2>&1 || need=1
{ command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ]; } || need=1
command -v tmux >/dev/null 2>&1 || need=1
if [ "$need" = 1 ] && command -v apt-get >/dev/null 2>&1; then
  log "pasang dependency..."
  $SUDO apt-get update -qq || true
  $SUDO apt-get install -y -qq curl ca-certificates tar openssh-server tmux || true
fi

# --- 2) sshd: host key + izin login + nyala (RELOAD, bukan restart, biar sesi gak putus) ---
log "siapin sshd..."
$SUDO mkdir -p /run/sshd
$SUDO ssh-keygen -A >/dev/null 2>&1 || true
$SUDO sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
$SUDO sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'               /etc/ssh/sshd_config 2>/dev/null || true
if pgrep -x sshd >/dev/null 2>&1; then
  $SUDO pkill -HUP -x sshd 2>/dev/null || true     # reload config tanpa mutusin sesi
else
  ($SUDO service ssh start || $SUDO /usr/sbin/sshd) >/dev/null 2>&1 || true
fi

# --- 3) auto-tmux (idempotent) ---
if ! grep -q "abelLabs auto-tmux" /etc/bash.bashrc 2>/dev/null; then
  $SUDO tee -a /etc/bash.bashrc >/dev/null <<'TMUX'

# === abelLabs auto-tmux (session persistent) ===
case $- in *i*)
  if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ] && [ -t 1 ]; then
    exec tmux new-session -A -s main
  fi
  ;;
esac
TMUX
fi

# --- 4) download frpc (retry) ---
if ! command -v frpc >/dev/null 2>&1 && [ ! -x /usr/local/bin/frpc ]; then
  log "download frpc ${FRP_VER} (${ARCH})..."
  ok=0
  for t in 1 2 3; do
    if curl -fsSL --retry 3 -o /tmp/frp.tgz \
        "https://github.com/fatedier/frp/releases/download/v${FRP_VER}/frp_${FRP_VER}_linux_${ARCH}.tar.gz"; then ok=1; break; fi
    warn "download gagal (coba $t/3)..."; sleep 3
  done
  [ "$ok" = 1 ] || { warn "gagal download frpc — cek koneksi internet mesin."; exit 1; }
  tar -xzf /tmp/frp.tgz -C /tmp
  $SUDO install -m755 "/tmp/frp_${FRP_VER}_linux_${ARCH}/frpc" /usr/local/bin/frpc
  rm -rf /tmp/frp.tgz "/tmp/frp_${FRP_VER}_linux_${ARCH}"
fi
FRPC="$(command -v frpc || echo /usr/local/bin/frpc)"

# --- 5) bersihin frpc lama (anti-dobel) ---
log "bersihin frpc lama (kalau ada)..."
$SUDO pkill -9 -f frpc-keepalive 2>/dev/null || true
$SUDO pkill -9 -f "$FRPC"        2>/dev/null || true
sleep 2

# --- 6) machine id stabil (nama proxy unik tapi tetap walau re-run) ---
MID="$( { cat /etc/machine-id 2>/dev/null || hostname; } | md5sum | cut -c1-8 )"

# --- 7) AUTO-DETECT port: coba 7001..7010, ambil yg kosong ---
mkcfg(){ # $1=port $2=name
  cat <<EOF
serverAddr = "$SERVER"
serverPort = $HUBPORT
auth.token = "$TOKEN"
loginFailExit = false
[[proxies]]
name = "$2"
type = "tcp"
localIP = "127.0.0.1"
localPort = $SSHPORT
remotePort = $1
EOF
}
CHOSEN=""; seen_login=0
log "nyari port kosong di hub..."
for P in $(seq "$PORT_MIN" "$PORT_MAX"); do
  mkcfg "$P" "ssh-${MID}-${P}" > /tmp/frpc-probe.toml
  "$FRPC" -c /tmp/frpc-probe.toml > /tmp/frpc-probe.log 2>&1 &
  pid=$!
  res=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if   grep -q "start proxy success" /tmp/frpc-probe.log 2>/dev/null; then res=ok; break
    elif grep -qiE "port already used|already in use|proxy.*already exists|port.*not allowed" /tmp/frpc-probe.log 2>/dev/null; then res=busy; seen_login=1; break
    elif grep -qiE "login to server success" /tmp/frpc-probe.log 2>/dev/null; then seen_login=1
    elif grep -qiE "i/o timeout|no such host|connection refused|dial tcp|authentication failed|token" /tmp/frpc-probe.log 2>/dev/null; then res=conn; break
    fi
    sleep 1
  done
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  case "$res" in
    ok)   CHOSEN="$P"; break ;;
    busy) log "port $P kepakai, lanjut..." ;;
    conn) warn "gak bisa konek/auth ke hub. Cek SERVER/PORT/TOKEN & internet:"; tail -3 /tmp/frpc-probe.log; exit 1 ;;
    *)    [ "$seen_login" = 0 ] && { warn "hub gak nyahut (cek $SERVER:$HUBPORT & internet):"; tail -3 /tmp/frpc-probe.log; exit 1; }
          log "port $P gak kebaca, lanjut..." ;;
  esac
done
[ -n "$CHOSEN" ] || { warn "port $PORT_MIN-$PORT_MAX penuh semua. Minta tambah preset di hub."; exit 1; }
NAME="ssh-${MID}-${CHOSEN}"
MESIN=$(( CHOSEN - PORT_MIN + 1 ))
log "dapet port ${G}$CHOSEN${N} → ini jadi '${G}Mesin $MESIN${N}' di web."
sleep 3   # kasih waktu hub lepasin port bekas probe

# --- 8) config final ---
$SUDO mkdir -p /etc/frp
mkcfg "$CHOSEN" "$NAME" | $SUDO tee /etc/frp/frpc.toml >/dev/null

# --- 9) jalanin persistent: systemd > keepalive(+cron) ---
$SUDO tee /usr/local/bin/frpc-keepalive >/dev/null <<'KA'
#!/bin/sh
while true; do /usr/local/bin/frpc -c /etc/frp/frpc.toml; sleep 5; done
KA
$SUDO chmod +x /usr/local/bin/frpc-keepalive
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  $SUDO tee /etc/systemd/system/frpc.service >/dev/null <<'UNIT'
[Unit]
Description=abel frpc
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now frpc >/dev/null 2>&1 || true
  MODE="systemd"
else
  $SUDO nohup /usr/local/bin/frpc-keepalive >/var/log/frpc.log 2>&1 &
  if command -v crontab >/dev/null 2>&1; then
    ( $SUDO crontab -l 2>/dev/null | grep -v frpc-keepalive; echo "@reboot /usr/local/bin/frpc-keepalive >/var/log/frpc.log 2>&1 &" ) | $SUDO crontab - 2>/dev/null || true
    MODE="keepalive+cron"
  else
    MODE="keepalive"
  fi
fi

# --- 10) verifikasi ---
ok2=""
for _ in 1 2 3 4 5 6 7 8; do
  if grep -q "start proxy success" /var/log/frpc.log 2>/dev/null \
     || $SUDO journalctl -u frpc --no-pager 2>/dev/null | grep -q "start proxy success"; then ok2=1; break; fi
  sleep 1
done
[ -n "$ok2" ] && STATUS="${G}✅ TERSAMBUNG${N}" || STATUS="${Y}⏳ lagi konek (tunggu beberapa detik)${N}"

cat <<EOF

==================================================
  $STATUS   (mode: $MODE)
  Port hub    : $CHOSEN
  Muncul jadi : "Mesin $MESIN" di web
  Login user  : root   (set password: ${C}sudo passwd root${N})
  Auto-tmux   : aktif (session gak mati walau putus)
==================================================
Buka web → klik "Mesin $MESIN" → masuk. Selesai!
EOF
