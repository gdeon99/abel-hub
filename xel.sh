#!/bin/bash

# ==========================================
# KONFIGURASI MINING XELIS (JANGAN LUPA CEK WALLET)
# ==========================================
# Ganti dengan alamat wallet Xelis kamu (diawali "xel:")
WALLET="xel:wjgl7e2ucav3jdp823st9x60rhxp4d9hwdfm0drtdwjj8dt64yfsq8k9y0g"

# Contoh pool HeroMiners (bisa kamu ganti ke pool favoritmu)
POOL="stratum+tcp://usw.vipor.net:5077"

WORKER_NAME="xelHlc1"

echo "=========================================="
echo " AUTO INSTALL SRBMINER (MINING XELIS)     "
echo "=========================================="
echo ">> Target Pool : $POOL"
echo ">> Nama Worker : $WORKER_NAME"
echo "=========================================="
sleep 3

echo "1. Menyiapkan bumbu-bumbu ekstraksi..."
apt-get update -y < /dev/null
apt-get install -y wget tar xz-utils util-linux procps < /dev/null

echo "2. Membersihkan sisa file lama (jika ada)..."
cd ~
rm -rf SRBMiner-Multi*

echo "3. Mendownload SRBMiner-Multi (Versi Terbaru)..."
# Menggunakan versi 2.7.5 agar mendukung algoritma xelhashv2
wget https://github.com/doktor83/SRBMiner-Multi/releases/download/2.7.5/SRBMiner-Multi-2-7-5-Linux.tar.xz

echo "4. Mengekstrak file (Tunggu beberapa detik)..."
tar -xf SRBMiner-Multi-2-7-5-Linux.tar.xz
cd SRBMiner-Multi-2-7-5

echo "5. Membunuh saingan (Miner lama yang nyangkut)..."
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
