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


# Fungsi untuk menghitung jumlah akun di file ws.json
countAccounts() {
    filePath="$1"
    count=$(grep "###" "$filePath" | sort | uniq | wc -l)  # Menghitung baris yang mengandung "###"
    echo $count  # Mengembalikan jumlah akun
}

# Fungsi untuk membersihkan layar
clearScreen() {
    clear  # Perintah untuk membersihkan layar terminal
}

# Fungsi utama untuk menampilkan menu dan menangani pilihan pengguna
xws() {
    ws=$(countAccounts "/etc/v2ray/config.json")  # Hitung jumlah akun

    clearScreen  # Bersihkan layar
    echo "============================"
    echo "[ <=   XTLS  WebSocket  => ]"
    echo "============================"
    echo -e "\nWS   : \033[1;32m$ws\033[0m"  # Tampilkan jumlah akun
    echo "============================"
    echo "          Menu  Create      "
    echo "01. Create Account Vmess"
    echo "02. Create Account Vless"
    echo "03. Create Account Trojan"
    echo "============================"
    echo "          Menu Trial        "
    echo "04. Trial Account Vmess"
    echo "05. Trial Account Vless"
    echo "06. Trial Account Trojan"
    echo "============================"
    echo "          Other Service"
    echo "07. Cek User Login"
    echo "08. Delete Account"
    echo "09. Extend Expired"
    echo "10. Cek Log Database"
    echo "11. List Database Account"
    echo "12. Change UUID / Password"
    echo "13. Unlock Account WebSocket"
    echo "14. Routing X-Ray WebSocket"
    echo "15. Change Limit IP X-Ray WebSocket"
    echo "16. Change Quota WebSocket"
    echo "17. Locked Account WebSocket"
    echo "============================"
    echo "   Press CTRL + C to Exit"
    echo "============================"

    # Input pilihan dari pengguna
    read -p "Input Option: " opws

    # Menangani pilihan berdasarkan input pengguna
    case $opws in
        1) clearScreen; add-vmess-ws ;;
        2) clearScreen; add-vless-ws ;;
        3) clearScreen; add-trojan-ws ;;
        4) clearScreen; trial-vmess-ws ;;
        5) clearScreen; trial-vless-ws ;;
        6) clearScreen; trial-trojan-ws ;;
        7) clearScreen; cek-xray-ws ;;
        8) clearScreen; delete-ws ;;
        9) clearScreen; extend-ws ;;
        10) clearScreen; log-database-xray-ws ;;
        11) clearScreen; list-xray-ws ;;
        12) clearScreen; change-id-ws ;;
        13) clearScreen; unlock-ws ;;
        14) clearScreen; routing-ws ;;
        15) clearScreen; change-limit-ip-ws ;;
        16) clearScreen; change-quota-ws;;
        17) clearScreen; locked-xray-ws;;
        *) clearScreen; xws ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xws
