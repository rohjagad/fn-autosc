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
sed -i '/#trojan$/{n;s/}/},\n### '"$user $exp"'\n{"password": "'""$uuid""'","email": "'""$user""'"}/}' /etc/xray/json/ws.json

# Restart Service
systemctl daemon-reload
systemctl restart xray@ws
systemctl restart quota-ws

# Konfigurasi Trojan WS TLS
link1="trojan://${uuid}@${domain}:443?path=%2ftrws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"

# Konfigurasi Trojan WS NonTLS
link2="trojan://${uuid}@${domain}:80?path=/trws&security=none&host=${domain}&type=ws#${user}"

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

Path: /trws
Network: WebSocket
Port TLS: 443, 2053, 2083, 2087, 2096
Port None: 80, 8880, 2052, 2082, 2095
======================
Link TLS : $link1
======================
Link None: $link2
======================
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/ws/${user}.log
echo 'sed -i "/### '"$user"' '"$exp"'/ {N;d}" /etc/xray/json/ws.json && sed -i -z '"'"'s/},\n *\]/}\n        ]/g'"'"' /etc/xray/json/ws.json && systemctl restart xray@ws && systemctl restart quota-ws && rm -fr /var/log/create/xray/ws/'"$user"'.log && rm -fr /etc/xray/limit/ip/xray/ws/'"$user"' && rm -fr /etc/xray/quota/ws/'"$user"' /etc/xray/quota/ws/'"$user"'_usage' | at now + 60 minutes >/dev/null 2>&1
clear
source /etc/funny/format.sh
format_display "$TEKS"
