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

# Function Send Log
send_log() {
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

        TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>HTTP UPGRADE MULTILOGIN</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️ Date      :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$user</code>
<b>📌 Login    :</b> <b>$cek / $limit</b>
<b>✳️ Status    :</b> <b>Locked </b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah dikunci dan total usage badwidth tidak akan di reset didalam server."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Database
username=$(grep '^###' /etc/xray/json/upgrade.json | cut -d ' ' -f 2 | sort | uniq)

# Loop through each username to check limits
for user in $username; do
    # Get the limit and current online stats for each user
    limit=$(grep "Limit IP:" /var/log/create/xray/http/${user}.log | awk '{print $3}')
    cek=$(xray api statsonline --server=127.0.0.1:10081 -email "$user" | jq -r '.stat.value')
    
    # Clear screen
    clear
    
    # Check if usage exceeds limit
    if [[ "$cek" -gt "$limit" ]]; then
        # Deleted Account
        sed -i "/^### $user $exp/,/^},{/d" /etc/xray/json/upgrade.json
        systemctl restart xray@upgrade >> /dev/null 2>&1
        send_log
#        rm -rf /etc/xray/quota/http/$user
#        rm -rf /etc/xray/quota/http/${user}_usage
#        rm -rf /etc/xray/quota/http/"${user}_usage"
        mv /var/log/create/xray/http/${user}.log /var/log/create/xray/http/${user}.locked

    else
        # If within limit, just clear the screen and display a message
        clear
    fi
done
