#!/bin/bash



echo "=========================================="

echo " AUTO INSTALL SRBMINER UBUNTU (ABEL) "

echo "=========================================="

echo "1. Menyiapkan bumbu-bumbu ekstraksi..."

apt-get update -y < /dev/null

apt-get install -y wget tar xz-utils < /dev/null



echo "2. Membersihkan sisa file lama (jika ada)..."

cd ~

rm -rf SRBMiner-Multi*



echo "3. Mendownload SRBMiner-Multi (Versi Stabil)..."

wget https://github.com/doktor83/SRBMiner-Multi/releases/download/2.4.7/SRBMiner-Multi-2-4-7-Linux.tar.xz



echo "4. Mengekstrak file (Tunggu beberapa detik)..."

tar -xf SRBMiner-Multi-2-4-7-Linux.tar.xz

cd SRBMiner-Multi-2-4-7



echo "5. Kalkulasi Pintar Kapasitas CPU (Maksimal 70%)..."

# Membaca total core pada PC/Laptop yang sedang dipakai

TOTAL_CORES=$(nproc)

# Menghitung 70% dari total core

TARGET_CORES=$((TOTAL_CORES * 70 / 100))



# Jika PC kentang (cuma 1 core), pastikan tetap jalan minimal 1

if [ "$TARGET_CORES" -lt 1 ]; then

    TARGET_CORES=1

fi



echo ">> PC ini terdeteksi memiliki $TOTAL_CORES Core."

echo ">> Miner otomatis dikunci hanya menggunakan $TARGET_CORES Core agar mesin tetap dingin!"



echo "=========================================="

echo " INSTALASI BERES! LANGSUNG GASS MINING! "

echo "=========================================="

# Mengeksekusi SRBMiner dengan batasan thread hasil kalkulasi di atas

./SRBMiner-MULTI --disable-gpu --algorithm verushash --pool stratum+tcp://na.luckpool.net:3960 --wallet RXkkitXME1JCdSLmEQi9avpHoY2udY2tFn.abel --password x --cpu-threads $TARGET_CORES
