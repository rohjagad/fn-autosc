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

# Menambahkan akun pada json
sed -i '/#vless$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","email": "'""$user""'"}/}' /etc/v2ray/config.json

# Restart Service
systemctl daemon-reload
systemctl restart v2ray
systemctl restart quota-ws

# Konfigurasi Vless WS TLS
vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"

# Konfigurasi Vless WS NoneTLS
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&security=none&encryption=none&host=${domain}&type=ws#${user}"

TEKS="
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
     \033[1;33mXray VLess WS\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Protokol: Vless
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
     Limit Detail

Limit IP: $ip
Quota   : $quota GB
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m

TLS: 443, 2053, 2083, 2087, 2096
Path: /vless
NoneTLS: 80, 8880, 2052, 2082, 2095
Network: WebSocket
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink TLS : $vlesslink1\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink None: $vlesslink2\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/ws/${user}.log
echo 'sed -i "/### '"$user"' '"$exp"'/ {N;d}" /etc/v2ray/config.json && sed -i -z '"'"'s/},\n *\]/}\n        ]/g'"'"' /etc/v2ray/config.json && systemctl restart v2ray && systemctl restart quota-ws && rm -fr /var/log/create/xray/ws/'"$user"'.log && rm -fr /etc/xray/limit/ip/xray/ws/'"$user"' && rm -fr /etc/xray/quota/ws/'"$user"' /etc/xray/quota/ws/'"$user"'_usage' | at now + 60 minutes >/dev/null 2>&1
clear
source /etc/funny/format.sh
format_display "$TEKS"
