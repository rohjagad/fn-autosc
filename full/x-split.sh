#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohfn-autosc-auth/1.23/izin.txt"
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


# Fungsi untuk menghitung jumlah akun di file split.json
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
xsplit() {
    split=$(countAccounts "/etc/xray/json/split.json")  # Hitung jumlah akun

    clearScreen  # Bersihkan layar
    echo "============================"
    echo "[ <=  XTLS  Split HTTP  => ]"
    echo "============================"
    echo -e "\nsplit   : \033[1;32m$split\033[0m"  # Tampilkan jumlah akun
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
    echo "13. Unlock Account SPLIT HTTP"
    echo "14. Routing X-Ray Split HTTP"
    echo "15. Change Limit IP X-Ray Split HTTP"
    echo "16. Change Quota Split HTTP"
    echo "17. Locked Account SPLIT HTTP"
    echo "============================"
    echo "   Press CTRL + C to Exit"
    echo "============================"

    # Input pilihan dari pengguna
    read -p "Input Option: " opsplit

    # Menangani pilihan berdasarkan input pengguna
    case $opsplit in
        1) clearScreen; add-vmess-split ;;
        2) clearScreen; add-vless-split ;;
        3) clearScreen; add-trojan-split ;;
        4) clearScreen; trial-vmess-split ;;
        5) clearScreen; trial-vless-split ;;
        6) clearScreen; trial-trojan-split ;;
        7) clearScreen; cek-xray-split ;;
        8) clearScreen; delete-split ;;
        9) clearScreen; extend-split ;;
        10) clearScreen; log-database-xray-split ;;
        11) clearScreen; list-xray-split ;;
        12) clearScreen; change-id-split ;;
        13) clearScreen; unlock-split ;;
        14) clearScreen; routing-split ;;
        15) clearScreen; change-limit-ip-split ;;
        16) clearScreen; change-quota-split;;
        17) clearScreen; locked-xray-split;;
        *) clearScreen; xsplit ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xsplit
