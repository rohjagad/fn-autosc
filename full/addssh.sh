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

clear_screen() {
    clear
}

read_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cat "$file_path" | xargs
    else
        echo ""
    fi
}

calculate_expiration_date() {
    local days="$1"
    date -d "+$days days" +"%Y-%m-%d"
}

send_telegram_notification() {
    local chat_id="$1"
    local key="$2"
    local message="$3"
    local api_url="https://api.telegram.org/bot${key}/sendMessage"
    local TIME="${TIME:-10}"

    curl -s --max-time $TIME --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$message" $api_url
}

create_ssh_user() {
    local username="$1"
    local password="$2"
    local expiration_date="$3"

    useradd -e "$expiration_date" -s /bin/false -M "$username"
    echo -e "${password}\n${password}" | passwd "$username"
    echo "$username:$password" | sudo chpasswd
}

main() {
    clear_screen

    local domain=$(read_file "/etc/xray/domain")
    local pub_key=$(read_file "/etc/slowdns/server.pub")
    local nameserver=$(read_file "/etc/slowdns/nsdomain")
    local chat_id=$(read_file "/etc/funny/.chatid")
    local key=$(read_file "/etc/funny/.keybot")

    echo "===================="
    echo " Create SSH Account "
    echo "===================="
    read -p "Username: " username
    read -p "Password: " password
    read -p "Limit IP: " iplimit
    read -p "Expired (days): " masaaktif

    clear_screen

    if [[ "$iplimit" -gt 0 ]]; then
        local limit_dir="/etc/xray/limit/ip/ssh"
        mkdir -p "$limit_dir"
        echo "$iplimit" > "${limit_dir}/${username}"
    fi

    local expiration_date=$(calculate_expiration_date "$masaaktif")
    create_ssh_user "$username" "$password" "$expiration_date"

    local expiry=$(chage -l "$username" | grep "Account expires" | awk -F": " '{print $2}' | xargs)

    local message=$(cat <<EOF
===================
[<= SSH Account =>]
===================
Domain     : $domain
Username   : $username
Password   : $password
Expired    : $expiry
Limit IP   : $iplimit
===================
DNS        : 1.1.1.1 / 8.8.8.8
Pub Key    : $pub_key
Nameserver : $nameserver
===================
OpenSSH    : 22, 3303
Dropbear   : 111, 109
NonTLS     : 80, 8880, 2052, 2082, 2086, 2095
Enhanced   : 2080
HTTP Proxy : 3128 ( Limit IP to Server )
OHP        : 9088
WS TLS     : 443, 2053, 2083, 2087, 2096
STUNNEL5   : 443
Slowdns    : 53
Udp Custom : 1-65535
Udp Request: 1-65535
BadVpn/Udpgw : 7300
===================
OVPN WS     : 2086
OVPN TCP    : 1194
Config OVPN : http://${domain}/web/tcp.ovpn
===================
EOF
)

    send_telegram_notification "$chat_id" "$key" "$message"

    local log_dir="/var/log/create/ssh"
    mkdir -p "$log_dir"
    echo "$message" > "${log_dir}/${username}.log"

    clear_screen
    echo "$message"
}

main
