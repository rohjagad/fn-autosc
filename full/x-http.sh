#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohtunnel-autosc-auth/main/izin.txt"
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
    echo "13. Unlock Account HTTP"
    echo "14. Routing X-Ray HTTP UPGRADE"
    echo "15. Change Limit IP HTTP UPGRADE"
    echo "16. Change Quota HTTP Upgrade"
    echo "17. Locked Account HTTP"
    echo "============================"
    echo "   Press CTRL + C to Exit"
    echo "============================"

    # Input pilihan dari pengguna
    read -p "Input Option: " ophttp

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
