#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

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

# Function Send Log
send_log() {
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

        TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>XTLS WEBSOCKET MULTILOGIN</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️ Date      :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$user</code>
<b>📌 Login    :</b> <b>$cek / $limit</b>
<b>✳️ Status    :</b> <b>Locked</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah dikunci dan total usage badwidth tidak akan di reset didalam server."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Database
username=$(grep '^###' /etc/xray/json/ws.json | cut -d ' ' -f 2 | sort | uniq)

# Bug 69: probe online-session statistics once before looping. The WS
# transport is served by V2Ray, which exposes no online-session metric, so
# "xray api statsonline" can never answer there. Bail out cleanly instead of
# raising integer-expression errors on every cron run.
if ! xray api statsonline --server=127.0.0.1:10080 -email probe 2>&1 | grep -q "not found"; then
    echo "IP limit check skipped: online statistics unavailable on 127.0.0.1:10080"
    exit 0
fi

for user in $username; do
    # Get the limit and current online stats for each user
    limit=$(grep "Limit IP:" /var/log/create/xray/ws/${user}.log | awk '{print $3}')
    # Bug 68 guard: 0 / missing / malformed limit = unlimited, never enforced
    if ! [[ "$limit" =~ ^[1-9][0-9]*$ ]]; then
        continue
    fi
    cek=$(xray api statsonline --server=127.0.0.1:10080 -email "$user" 2>/dev/null | jq -r '.stat.value // empty' 2>/dev/null)
    # Skip when the online count is not a number (API error / unavailable)
    if ! [[ "$cek" =~ ^[0-9]+$ ]]; then
        continue
    fi
    
    # Clear screen
    clear
    
    # Check if usage exceeds limit
    if [[ "$cek" -gt "$limit" ]]; then
        # Deleted Account
        # Bug 68: the legacy range pattern /^### $user $exp/,/^},{/d never
        # matched its end address (no line starts with "},{") while $exp was
        # undefined, so a triggered limit deleted the account block plus
        # everything after it to the end of the file. Remove only the account.
        exp=$(grep -wE "^### $user" "/etc/xray/json/ws.json" | cut -d ' ' -f 3 | sort | uniq)
        if [[ -n "$exp" ]]; then
            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/ws.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
            systemctl restart xray@ws >> /dev/null 2>&1
            send_log
            mv /var/log/create/xray/ws/${user}.log /var/log/create/xray/ws/${user}.locked
        fi

    else
        # If within limit, just clear the screen and display a message
        clear
    fi
done
