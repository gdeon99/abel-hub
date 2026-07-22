#!/bin/bash
set -euo pipefail

# ==========================================
# KONFIGURASI MINING XELIS (JANGAN LUPA CEK WALLET)
# ==========================================
WALLET="xel:wjgl7e2ucav3jdp823st9x60rhxp4d9hwdfm0drtdwjj8dt64yfsq8k9y0g"
POOL="stratum+tcp://usw.vipor.net:5077"
WORKER_NAME="xelHlc1"
ALGO="xelishashv3"          # ganti ke xelishashv2 kalau pool kamu masih minta ini
SRB_VERSION="3.4.6"         # cek versi terbaru: https://github.com/doktor83/SRBMiner-Multi/releases
SRB_TAG="${SRB_VERSION//./-}"

echo "=========================================="
echo " AUTO INSTALL SRBMINER (MINING XELIS)     "
echo "=========================================="
echo ">> Target Pool : $POOL"
echo ">> Nama Worker : $WORKER_NAME"
echo ">> Algoritma   : $ALGO"
echo ">> Versi Miner : $SRB_VERSION"
echo "=========================================="
sleep 3

echo "1. Menyiapkan dependencies..."
sudo apt-get update -y
sudo apt-get install -y wget tar xz-utils util-linux procps

echo "2. Membersihkan sisa file lama (jika ada)..."
cd ~
rm -rf SRBMiner-Multi*

echo "3. Mendownload SRBMiner-Multi v${SRB_VERSION}..."
DOWNLOAD_URL="https://github.com/doktor83/SRBMiner-Multi/releases/download/${SRB_VERSION}/SRBMiner-Multi-${SRB_TAG}-Linux.tar.xz"
if ! wget -q --show-progress "$DOWNLOAD_URL" -O "SRBMiner-Multi-${SRB_TAG}-Linux.tar.xz"; then
    echo "GAGAL download dari: $DOWNLOAD_URL"
    echo "Cek versi/tag terbaru di: https://github.com/doktor83/SRBMiner-Multi/releases"
    exit 1
fi

echo "4. Mengekstrak file..."
tar -xf "SRBMiner-Multi-${SRB_TAG}-Linux.tar.xz"
cd "SRBMiner-Multi-${SRB_TAG}"

echo "5. Membunuh proses miner lama yang nyangkut..."
pkill -9 -f SRBMiner-MULTI 2>/dev/null || true
pkill -9 -f ccminer 2>/dev/null || true

echo "6. Info sistem..."
TOTAL_CORES=$(nproc)
echo ">> Mesin terdeteksi memiliki $TOTAL_CORES core."

echo "=========================================="
echo " INSTALASI SELESAI! MULAI MINING XELIS!   "
echo "=========================================="

chmod +x ./SRBMiner-MULTI

nice -n -20 ./SRBMiner-MULTI \
    --disable-gpu \
    --algorithm "$ALGO" \
    --pool "$POOL" \
    --wallet "${WALLET}.${WORKER_NAME}" \
    --password xecho "5. Membunuh saingan (Miner lama yang nyangkut)..."
pkill -9 -f SRBMiner-MULTI > /dev/null 2>&1 || true
pkill -9 -f ccminer > /dev/null 2>&1 || true

echo "6. Mengaktifkan Mode Buas (Max Cores & Priority)..."
TOTAL_CORES=$(nproc)
echo ">> Mesin terdeteksi memiliki $TOTAL_CORES Core."
echo ">> Seluruh $TOTAL_CORES Core akan diperas maksimal tanpa sisa!"

echo "=========================================="
echo " INSTALASI BERES! LANGSUNG GASS MINING XELIS! "
echo "=========================================="
# --algorithm xelhashv2 khusus untuk mining Xelis
nice -n -20 ./SRBMiner-MULTI --disable-gpu --algorithm xelhashv2 --pool $POOL --wallet $WALLET.$WORKER_NAME --password x
