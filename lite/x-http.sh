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
        echo "Your IP is not in the database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"
    }

    output
clear

# Fungsi untuk menghitung jumlah akun di file http.json
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
xhttp() {
    http=$(countAccounts "/etc/xray/json/upgrade.json")  # Hitung jumlah akun

    clearScreen  # Bersihkan layar
    echo "============================"
    echo "[ <=  XTLS HTTP UPGRADE => ]"
    echo "============================"
    echo -e "\nhttp   : \033[1;32m$http\033[0m"  # Tampilkan jumlah akun
    echo "============================"
    echo "          Create Account    "
    echo "01. Create VMess Account"
    echo "02. Create VLess Account"
    echo "03. Create Trojan Account"
    echo "============================"
    echo "          Trial Account     "
    echo "04. Trial VMess Account"
    echo "05. Trial VLess Account"
    echo "06. Trial Trojan Account"
    echo "============================"
    echo "          Manage Account"
    echo "07. Check Online Users"
    echo "08. Delete Account"
    echo "09. Extend Account"
    echo "10. Check Database Logs"
    echo "11. List All Accounts"
    echo "12. Change UUID / Password"
    echo "13. Unlock HTTP Account"
    echo "14. Xray Routing Config"
    echo "15. Change HTTP IP Limit"
    echo "16. Change HTTP Quota Limit"
    echo "17. Lock HTTP Account"
    echo "============================"
    echo "   Press [Ctrl + C] to exit"
    echo "============================"

    # Input pilihan dari pengguna
    read -p "Input option: " ophttp

    # Menangani pilihan berdasarkan input pengguna
    case $ophttp in
        1) clearScreen; add-vmess-http ;;
        2) clearScreen; add-vless-http ;;
        3) clearScreen; add-trojan-http ;;
        4) clearScreen; trial-vmess-http ;;
        5) clearScreen; trial-vless-http ;;
        6) clearScreen; trial-trojan-http ;;
        7) clearScreen; cek-xray-http ;;
        8) clearScreen; delete-http ;;
        9) clearScreen; extend-http ;;
        10) clearScreen; log-database-xray-http ;;
        11) clearScreen; list-xray-http ;;
        12) clearScreen; change-id-http ;;
        13) clearScreen; unlock-http ;;
        14) clearScreen; routing-http ;;
        15) clearScreen; change-limit-ip-http ;;
        16) clearScreen; change-quota-http;;
	17) clearScreen; locked-xray-http;;
        *) clearScreen; xhttp ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xhttp
