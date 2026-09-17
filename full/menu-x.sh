#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/1.23/izin.txt"
    LOCAL_IP=$(curl -s ifconfig.me) # Mendapatkan IP lokal

    # Fungsi menghitung sisa waktu
    calculate_remaining_days() {
        local today=$(date +%s)
        local expired_date=$(date -d "$1" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Tanggal kadaluwarsa tidak valid."
            exit 1
        fi
        echo $(( (expired_date - today) / 86400 ))
    }

    # Unduh izin dan validasi
    clear
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL" || { echo "Gagal mengunduh izin."; exit 1; })

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
        echo "Izin telah kadaluwarsa."
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

# Color
red='\e[1;31m'
green='\e[1;32m'
#pink='\e[1;35m'
NC='\e[0m'

menu-x() {

# Status Service
status="$(systemctl show nginx.service --no-page)"
status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status_text}" == "active" ]
then
echo -e "${NC}: "${green}"running"$NC" ✓"
else
echo -e "${NC}: "$red"not running (Error)"$NC" "
fi

# Total Akun
ws=$(cat /etc/v2ray/config.json | grep "###" | sort | uniq | wc -l)
http=$(cat /etc/xray/json/upgrade.json | grep "###" | sort | uniq | wc -l)
gpc=$(cat /etc/xray/json/grpc.json | grep "###" | sort | uniq | wc -l)
split=$(cat /etc/xray/json/split.json | grep "###" | sort | uniq | wc -l)

clear
echo -e "
${NC}
============================
[ <= MENU XTLS $(status="$(systemctl show nginx.service --no-page)"
status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status_text}" == "active" ]
then
echo -e "${NC}: "${green}"running"$NC" ✓"
else
echo -e "${NC}: "$red"not running (Error)"$NC" "
fi) => ]
============================
Total Account

WS   : $ws
HTTP : $http
Split: $split
gRPC : $gpc
============================
1. Menu WebSocket / WS
2. Menu HTTP UPGRADE / HTTP
3. Menu Split HTTP / Split
4. Menu gRPC / XTLS gRPC
============================
   Press CTRL + C to Exit
============================
"
read -p "Input Option: " opws
case $opws in
1) clear ; x-ws ;;
2) clear ; x-http ;;
3) clear ; x-split ;;
4) clear ; x-grpc ;;
*) clear ; menu-x ;;
esac
}

menu-x
