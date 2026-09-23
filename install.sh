#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

if grep -q "bullseye" /etc/os-release 2>/dev/null; then
    if ! grep -qs "deb.debian.org/debian.*bullseye" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "deb http://deb.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list
        echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list
        apt update -y >/dev/null 2>&1 || true
    fi
fi

hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
ungu="\033[0;35m"
Xark="\033[0m"
BlueCyan="\033[5;36m"

function permision() {

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s ifconfig.me) # Mendapatkan IP lokal

    # Fungsi menghitung sisa waktu
    calculate_remaining_days() {
        local today=$(date +%s)
        local expired_date=$(date -d "$1" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Invalid expiration date."
            exit 1
        fi
        echo $(( (expired_date - today) / 86400 ))
    }

    # Unduh izin dan validasi
    clear
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL" || { echo "Failed to download permissions."; exit 1; })

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP doesn’t have on database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"
    }

    output
clear
}

function full() {
curl -fsSL "${hosting}/installer/full.sh" -o full.sh || wget -q "${hosting}/installer/full.sh"
chmod +x full.sh
./full.sh
rm -fr full.sh
}

function lite() {
curl -fsSL "${hosting}/installer/lite.sh" -o lite.sh || wget -q "${hosting}/installer/lite.sh"
chmod +x lite.sh
./lite.sh
rm -fr lite.sh
}

function request() {
clear

echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "
echo -e "${ungu}            FN AutoSC      ${Xark} "
echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "


while true; do
    read -p "Input Type Script (full / lite) : " domain
    # Cek jika input kosong
    if [[ -z "$domain" ]]; then
        echo "Tipe tidak boleh kosong. Silakan coba lagi."
        continue
    fi

    # Jika lolos validasi
    echo "Tipe valid: $domain"
    break
done


clear

# Memilih Installasi
if [[ -z $domain || ! $domain =~ ^(full|lite)$ ]]; then
    echo "Invalid or empty sc version. Defaulting to lite version."
    domain="lite"
fi

if [[ $domain == "full" ]]; then
full
elif [[ $domain == "lite" ]]; then
lite
fi
}

function rere() {
permision
request
}

rere
