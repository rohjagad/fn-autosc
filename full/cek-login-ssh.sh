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

# Fungsi untuk mencetak teks dengan warna
function print_color {
    echo -e "\033[1;34m$1\033[0m"  # Biru untuk header
}

# Memeriksa apakah file log tersedia
LOG=""
if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
else
    echo "Log file not found!"
    exit 1
fi

# Membaca Log
grep -i "dropbear" $LOG | grep -i "Password auth succeeded" > /tmp/login-db.txt
grep -i sshd $LOG | grep -i "Accepted password for" > /tmp/login-ssh.txt
countdb=$(cat /tmp/login-db.txt | sort | uniq | wc -l )
countsh=$(cat /tmp/login-ssh.txt | sort | uniq | wc -l)

# Fungsi untuk menampilkan login Dropbear dengan PID dan Limit IP
function show_dropbear_logins {
    print_color "═══════════[ Dropbear User Login ]═══════════"
    printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "Username" "IP Address" "Login Count" "PID" "Limit IP"
    echo "──────────────────────────────"
    grep -i "dropbear" $LOG | grep -i "Password auth succeeded" | awk '{print $10, $12, $3}' | sort | uniq -c | while read -r count user ip pid; do
        # Menghapus tanda petik tunggal pada username
        user=$(echo "$user" | sed "s/'//g")

        # Mendapatkan limit IP dari file terkait
        LIMIT_IP=$(get_limit_ip $user)

        # Mengambil angka PID setelah titik dua dan bukan keseluruhan
        PID=$(echo $ip | cut -d: -f2)

        # Cek jika PID ada, jika tidak maka jangan tampilkan
        if [ -z "$PID" ]; then
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countdb" "N/A" "$LIMIT_IP"
        else
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countdb" "$PID" "$LIMIT_IP"
        fi
    done
    echo ""
}

# Fungsi untuk menampilkan login OpenSSH dengan PID dan Limit IP
function show_openssh_logins {
    print_color "═══════════[ OpenSSH User Login ]═══════════"
    printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "Username" "IP Address" "Login Count" "PID" "Limit IP"
    echo "──────────────────────────────"
    grep -i sshd $LOG | grep -i "Accepted password for" | awk '{print $9, $11, $3}' | sort | uniq -c | while read -r count user ip pid; do
        # Menghapus tanda petik tunggal pada username
        user=$(echo "$user" | sed "s/'//g")

        # Mendapatkan limit IP dari file terkait
        LIMIT_IP=$(get_limit_ip $user)

        # Mengambil angka PID setelah titik dua dan bukan keseluruhan
        PID=$(echo $ip | cut -d: -f2)

        # Cek jika PID ada, jika tidak maka jangan tampilkan
        if [ -z "$PID" ]; then
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countsh" "N/A" "$LIMIT_IP"
        else
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countsh" "$PID" "$LIMIT_IP"
        fi
    done
    echo ""
}

# Fungsi untuk mendapatkan Limit IP dari file tertentu
function get_limit_ip {
    USER=$1
    LIMIT_FILE="/etc/xray/limit/ip/ssh/$USER"

    if [ -f "$LIMIT_FILE" ]; then
        LIMIT=$(cat "$LIMIT_FILE")
        if [ "$LIMIT" == "Unlimited" ]; then
            echo "Unlimited"
        else
            echo "$LIMIT"
        fi
    else
        echo "2"  # Default limit
    fi
}

# Fungsi untuk menampilkan total aktif user
function show_total_users {
    total_users=$(grep -i "Accepted password" $LOG | wc -l)
    print_color "═══════════════════════════════════════════════"
    print_color "Total Active Users: $total_users"
    print_color "═══════════════════════════════════════════════"
}

rm -fr /tmp/login-ssh.txt
rm -fr /tmp/login-db.txt

# Menampilkan hasil logins
show_dropbear_logins
show_openssh_logins
show_total_users