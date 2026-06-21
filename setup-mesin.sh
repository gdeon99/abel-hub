#!/usr/bin/env bash
# ============================================================================
#  setup-mesin.sh — JALANKAN DI TIAP MESIN UBUNTU (yang gak punya IP public).
#  Mesin bakal "nelpon keluar" ke hub, daftarin SSH-nya. NAT/no-IP = gak masalah.
#
#  Cara pakai:
#    ./setup-mesin.sh <HOST_HUB> <PORT_HUB> <TOKEN> <REMOTE_PORT>
#
#  Contoh (HOST & PORT dari Railway TCP Proxy):
#    ./setup-mesin.sh shuttle.proxy.rlwy.net 15140 token-rahasia-kuat 7001
#
#  REMOTE_PORT: 7001 buat Mesin 1, 7002 buat Mesin 2, 7003 buat Mesin 3.
# ============================================================================
set -e

FRP_SERVER="${1:?Kasih alamat hub (host TCP Proxy Railway). Contoh: shuttle.proxy.rlwy.net}"
FRP_PORT="${2:?Kasih port hub (dari Railway TCP Proxy). Contoh: 15140}"
FRP_TOKEN="${3:?Kasih token frp (harus sama dgn FRP_TOKEN di hub)}"
REMOTE_PORT="${4:?Kasih remote port: 7001 (Mesin 1) / 7002 (Mesin 2) / 7003 (Mesin 3)}"
LOCAL_SSH="${5:-22}"
FRP_VER="0.69.1"

# sudo cuma kalau bukan root
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# pastikan ssh server ada (mesin harus bisa di-SSH)
if ! command -v sshd >/dev/null 2>&1 && [ ! -x /usr/sbin/sshd ]; then
  echo "[mesin] openssh-server belum ada, install..."
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq openssh-server
fi

# auto-tmux: session TETAP NYALA walau koneksi putus (sama kayak hub)
command -v tmux >/dev/null 2>&1 || { echo "[mesin] install tmux..."; $SUDO apt-get install -y -qq tmux; }
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
  echo "[mesin] ✅ auto-tmux terpasang."
fi

# deteksi arsitektur (amd64 / arm64 / arm)
case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  armv7l|armhf)  ARCH=arm ;;
  *) echo "[mesin] arsitektur $(uname -m) belum didukung"; exit 1 ;;
esac

echo "[mesin] download frpc ${FRP_VER} (${ARCH})..."
curl -fsSL -o /tmp/frp.tar.gz \
  "https://github.com/fatedier/frp/releases/download/v${FRP_VER}/frp_${FRP_VER}_linux_${ARCH}.tar.gz"
tar -xzf /tmp/frp.tar.gz -C /tmp
$SUDO mv "/tmp/frp_${FRP_VER}_linux_${ARCH}/frpc" /usr/local/bin/frpc
$SUDO chmod +x /usr/local/bin/frpc
rm -rf /tmp/frp.tar.gz "/tmp/frp_${FRP_VER}_linux_${ARCH}"

echo "[mesin] tulis config /etc/frp/frpc.toml..."
$SUDO mkdir -p /etc/frp
$SUDO tee /etc/frp/frpc.toml >/dev/null <<TOML
serverAddr = "${FRP_SERVER}"
serverPort = ${FRP_PORT}
auth.token = "${FRP_TOKEN}"

[[proxies]]
name = "mesin-${REMOTE_PORT}-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${LOCAL_SSH}
remotePort = ${REMOTE_PORT}
TOML

# jalanin via systemd kalau ada (biar otomatis nyala lagi pas reboot)
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  echo "[mesin] pasang service systemd..."
  $SUDO tee /etc/systemd/system/frpc.service >/dev/null <<UNIT
[Unit]
Description=frp client - konek ke hub
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
  $SUDO systemctl enable --now frpc
  echo "[mesin] ✅ frpc jalan via systemd. Cek: sudo systemctl status frpc"
else
  echo "[mesin] systemd gak ada — pakai keepalive + nohup..."
  # script yang muter terus: auto-restart kalau frpc mati
  $SUDO tee /usr/local/bin/frpc-keepalive >/dev/null <<"KA"
#!/bin/sh
while true; do
  /usr/local/bin/frpc -c /etc/frp/frpc.toml
  sleep 5
done
KA
  $SUDO chmod +x /usr/local/bin/frpc-keepalive
  # jalanin sekarang di background
  $SUDO sh -c 'nohup /usr/local/bin/frpc-keepalive >/var/log/frpc.log 2>&1 &'
  # auto-start pas reboot (cron @reboot — gak butuh systemd)
  if command -v crontab >/dev/null 2>&1; then
    ( $SUDO crontab -l 2>/dev/null | grep -v frpc-keepalive; \
      echo "@reboot /usr/local/bin/frpc-keepalive >/var/log/frpc.log 2>&1 &" ) | $SUDO crontab -
    echo "[mesin] ✅ frpc jalan (keepalive) + auto-start via cron @reboot."
  else
    echo "[mesin] ✅ frpc jalan (keepalive). Buat auto-start reboot, tambahkan ke /etc/rc.local:"
    echo "        /usr/local/bin/frpc-keepalive >/var/log/frpc.log 2>&1 &"
  fi
fi

echo "[mesin] ✅ SELESAI. Mesin ini sekarang nongol di hub sebagai port ${REMOTE_PORT}."
