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



echo "5. Mengatur Kapasitas CPU..."

TARGET_CORES=2

echo ">> Miner otomatis dikunci menggunakan $TARGET_CORES Core untuk Userland HP!"



echo "=========================================="

echo " INSTALASI BERES! LANGSUNG GASS MINING! "

echo "=========================================="

# Mengeksekusi SRBMiner dengan batasan thread hasil kalkulasi di atas

./SRBMiner-MULTI --disable-gpu --algorithm verushash --pool stratum+tcp://eu.luckpool.net:3960 --wallet RXkkitXME1JCdSLmEQi9avpHoY2udY2tFn.abel --password x --cpu-threads $TARGET_CORES
