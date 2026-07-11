#!/bin/bash



# ==========================================

# KONFIGURASI MINING (JANGAN LUPA CEK WALLET)

# ==========================================

WALLET="RXkkitXME1JCdSLmEQi9avpHoY2udY2tFn"

POOL="stratum+tcp://de.vipor.net:5040"



# Membuat nama worker otomatis (contoh: abel.phone732)

# Menggunakan $RANDOM agar menghasilkan angka acak 1-999 di setiap HP

WORKER_NAME="SATURN1"



echo "=========================================="

echo " AUTO INSTALL SRBMINER (MODE RATA KANAN) "

echo "=========================================="

echo ">> Target Pool : $POOL"

echo ">> Nama Worker : $WORKER_NAME"

echo "=========================================="

sleep 3



echo "1. Menyiapkan bumbu-bumbu ekstraksi..."

apt-get update -y < /dev/null

# Menambahkan procps dan util-linux untuk manajemen prioritas proses

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

# Otomatis membunuh proses ccminer atau srbminer yang berjalan diam-diam

pkill -9 -f SRBMiner-MULTI > /dev/null 2>&1 || true

pkill -9 -f ccminer > /dev/null 2>&1 || true



echo "6. Mengaktifkan Mode Buas (Max Cores & Priority)..."

TOTAL_CORES=$(nproc)

echo ">> Mesin terdeteksi memiliki $TOTAL_CORES Core."

echo ">> Seluruh $TOTAL_CORES Core akan diperas maksimal tanpa sisa!"



echo "=========================================="

echo " INSTALASI BERES! LANGSUNG GASS MINING! "

echo "=========================================="

# 'nice -n -20' memaksa Linux memprioritaskan CPU hanya untuk miner ini.

# Variabel $WALLET dan $WORKER_NAME dipanggil di baris paling bawah.

nice -n -20 ./SRBMiner-MULTI --disable-gpu --algorithm verushash --pool $POOL --wallet $WALLET.$WORKER_NAME --password x
