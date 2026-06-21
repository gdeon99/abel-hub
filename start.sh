#!/usr/bin/env bash
# ============================================================================
#  start.sh — entrypoint container hub.
#  Siapin password + sshd + config sshwifty, lalu jalanin supervisor.
# ============================================================================
set -e

# ---- default env (boleh dioverride dari Railway Variables) ----
: "${SSH_PASSWORD:=changeme}"            # password login user 'app' di dalam container
: "${SSHWIFTY_SHAREDKEY:=changeme}"      # password buka halaman web sshwifty
: "${SSH_USER:=app}"                     # user yang dipakai login
: "${FRP_TOKEN:=changeme}"               # token rahasia frps (WAJIB kuat di production!)
: "${MACHINE_USER:=ubuntu}"              # user default buat login ke 3 mesin Ubuntu

echo "[start] menyiapkan container hub..."

# ---- 1) set password user login ----
echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
echo "[start] password user '${SSH_USER}' diset."

# ---- 2) siapin sshd (host key + folder run) ----
mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1 || true
# izinkan login password (default debian biasanya sudah, ini jaga-jaga)
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "[start] sshd siap."

# ---- 3) generate config sshwifty (+ preset 'Hub' biar tinggal klik) ----
mkdir -p /etc/sshwifty
cat > /etc/sshwifty/sshwifty.conf.json <<JSON
{
  "SharedKey": "${SSHWIFTY_SHAREDKEY}",
  "DialTimeout": 5,
  "Servers": [
    {
      "ListenInterface": "0.0.0.0",
      "ListenPort": 8182,
      "InitialTimeout": 10,
      "ReadTimeout": 120,
      "WriteTimeout": 120,
      "HeartbeatTimeout": 15,
      "ReadDelay": 10,
      "WriteDelay": 10
    }
  ],
  "Presets": [
    {
      "Title": "Hub (container ini)",
      "Type": "SSH",
      "Host": "127.0.0.1:22",
      "Meta": { "User": "${SSH_USER}", "Authentication": "Password", "Encoding": "utf-8" }
    },
    {
      "Title": "Mesin 1",
      "Type": "SSH",
      "Host": "127.0.0.1:7001",
      "Meta": { "User": "${MACHINE_USER}", "Authentication": "Password", "Encoding": "utf-8" }
    },
    {
      "Title": "Mesin 2",
      "Type": "SSH",
      "Host": "127.0.0.1:7002",
      "Meta": { "User": "${MACHINE_USER}", "Authentication": "Password", "Encoding": "utf-8" }
    },
    {
      "Title": "Mesin 3",
      "Type": "SSH",
      "Host": "127.0.0.1:7003",
      "Meta": { "User": "${MACHINE_USER}", "Authentication": "Password", "Encoding": "utf-8" }
    }
  ]
}
JSON
echo "[start] config sshwifty dibuat (port 8182, preset Hub + Mesin 1/2/3)."

# ---- 3b) generate config frps (server reverse-tunnel buat mesin) ----
mkdir -p /etc/frp
cat > /etc/frp/frps.toml <<TOML
bindPort = 7000
auth.token = "${FRP_TOKEN}"
TOML
echo "[start] config frps dibuat (bindPort 7000, token diset)."

# ---- 4) cloudflared: tambah ke supervisor cuma kalau token ada ----
if [ -n "${CF_TUNNEL_TOKEN:-}" ]; then
  cat > /etc/supervisor/conf.d/cloudflared.conf <<CONF
[program:cloudflared]
command=/usr/local/bin/cloudflared --no-autoupdate tunnel run --token ${CF_TUNNEL_TOKEN}
autorestart=true
startretries=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
priority=30
CONF
  echo "[start] cloudflared AKTIF (token terdeteksi)."
else
  rm -f /etc/supervisor/conf.d/cloudflared.conf
  echo "[start] cloudflared SKIP (CF_TUNNEL_TOKEN kosong) — mode tes lokal."
fi

# ---- 5) jalanin semua proses via supervisor (foreground) ----
echo "[start] menjalankan supervisor..."
exec supervisord -c /etc/supervisor/supervisord.conf -n
