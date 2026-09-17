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

clear
    echo -e "\n======================================="
    echo -e "          [ <= MENU SSH  => ]          "
    echo -e "======================================="
    echo -e "  1.  Create SSH Account               "
    echo -e "  2.  Trial SSH Account                "
    echo -e "  3.  Delete SSH Account               "
    echo -e "  4.  Cek User Login SSH               "
    echo -e "  5.  Cek Log SSH Account              "
    echo -e "  6.  Extend Expired SSH               "
    echo -e "  7.  List Total Account SSH           "
    echo -e "  8.  Change Password Account SSH      "
    echo -e "  9.  Change Limit IP Account SSH      "
    echo -e "======================================="
    echo -e "       CTRL + C To Exit                "
    echo -e "======================================="
    read -p "Input Option: " aws
    case $aws in
    1) clear ; addssh ;;
    2) clear ; trial-ssh ;;
    3) clear ; delete-ssh ;;
    4) clear ; cek-login-ssh ;;
    5) clear ; log-acc-ssh ;;
    6) clear ; extend-ssh ;;
    7) clear ; list-ssh ;;
    8) clear ; pwd-ssh ;;
    9) clear ; limit-ip ;;
    esac
