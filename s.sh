#!/bin/bash
echo "=========================================="
echo " AUTO INSTALL SRBMINER KRYPTEX (RANDOMX)  "
echo "=========================================="
echo "1. Menyiapkan bumbu-bumbu ekstraksi..."
apt-get update -y < /dev/null
apt-get install -y wget tar xz-utils util-linux procps < /dev/null

echo "2. Membersihkan sisa file lama (jika ada)..."
cd ~
rm -rf SRBMiner-Multi*

echo "3. Mendownload SRBMiner-Multi (Versi Stabil)..."
wget https://github.com/doktor83/SRBMiner-Multi/releases/download/2.4.7/SRBMiner-Multi-2-4-7-Linux.tar.xz

echo "4. Mengekstrak file (Tunggu beberapa detik)..."
tar -xf SRBMiner-Multi-2-4-7-Linux.tar.xz
cd SRBMiner-Multi-2-4-7

echo "5. Membunuh saingan (Miner lama yang nyangkut)..."
pkill -9 -f SRBMiner-MULTI > /dev/null 2>&1 || true
pkill -9 -f ccminer > /dev/null 2>&1 || true

echo "6. Mengaktifkan Mode Buas (Max Cores & Priority)..."
TOTAL_CORES=$(nproc)
echo ">> Mesin terdeteksi memiliki $TOTAL_CORES Core."
echo ">> Seluruh $TOTAL_CORES Core akan diperas maksimal untuk RandomX!"
echo "=========================================="
echo " INSTALASI BERES! LANGSUNG GASS MINING! "
echo "=========================================="

# Parameter eksekusi diubah ke algoritma RandomX dan pool Kryptex
nice -n -20 ./SRBMiner-MULTI --disable-gpu --algorithm randomx --pool xmr.kryptex.network:7029 --wallet sheldenjplankton@gmail.com/Abel --password x
