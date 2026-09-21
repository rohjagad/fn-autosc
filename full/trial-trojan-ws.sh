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

domain=$(cat /etc/xray/domain)
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
clear
user=trial`</dev/urandom tr -dc 0-9 | head -c3`
masaaktif="1"
quota="1"
ip="1"
clear

# Limit Quota
if [[ $quota -gt 0 ]]; then
echo -e "$[$quota * 1024 * 1024 * 1024]" > /etc/xray/quota/ws/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/ws/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%y-%m-%d"`

# Generate UUID
uuid=$(xray uuid)

# Menambahkan Akun di Database
sed -i '/#trojan$/a\### '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/v2ray/config.json

# Restart Service
systemctl daemon-reload
systemctl restart v2ray
systemctl restart quota-ws

# Konfigurasi Trojan WS TLS
link1="trojan://${uuid}@${domain}:443?path=%2ftrojanws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"

# Konfigurasi Trojan WS NonTLS
link2="trojan://${uuid}@${domain}:80?path=/trojanws&security=none&host=${domain}&type=ws#${user}"

TEKS="
======================
   Trojan WebSocket
======================

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Limit IP: $ip
Quota   : $quota GB
Protokol: Trojan
======================

Path: /trojanws
Network: WebSocket
Port TLS: 443, 2053, 2083, 2087, 2096
Port None: 80, 8880, 2052, 2082, 2095
======================
Link TLS : $link1
======================
Link None: $link2
======================
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/ws/${user}.log
echo "sed -i "/### $user $exp/ {N;d}" /etc/v2ray/config.json && systemctl restart v2ray && systemctl restart quota-ws && rm -fr /var/log/create/xray/ws/${user}.log && rm -fr /etc/xray/limit/ip/xray/ws/$user && rm -fr /etc/xray/quota/ws/$user" | at now + 60 minutes >/dev/null 2>&1
clear
echo -e "$TEKS"
