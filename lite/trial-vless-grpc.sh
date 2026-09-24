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
echo -e "$[$quota * 1024 * 1024 * 1024]" > /etc/xray/quota/grpc/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/grpc/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%y-%m-%d"`

# Generate UUID
uuid=$(xray uuid)

# Menambahkan akun pada json
sed -i '/#vless$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","email": "'""$user""'"}/}' /etc/xray/json/grpc.json

# Restart Service
systemctl daemon-reload
systemctl restart xray@grpc
systemctl restart quota-grpc

# Konfigurasi Vless gRPC
vlesslink1="vless://$uuid@$domain:443?mode=gun&security=tls&encryption=none&authority=$domain&type=grpc&serviceName=vless-grpc&sni=$domain#${user}"

TEKS="
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
    \033[1;33mXray VLess gRPC\033[0m
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Protokol: Vless
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
     Limit Detail

Limit IP: $ip
Quota   : $quota GB
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m

Port: 443, 2053, 2083, 2087, 2096
Network: gRPC
Service Name: vless-grpc
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink TLS : $vlesslink1\033[0m
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/grpc/${user}.log
echo 'sed -i "/### '"$user"' '"$exp"'/ {N;d}" /etc/xray/json/grpc.json && sed -i -z '"'"'s/},\n *\]/}\n        ]/g'"'"' /etc/xray/json/grpc.json && systemctl restart xray@grpc && systemctl restart quota-grpc && rm -fr /var/log/create/xray/grpc/'"$user"'.log && rm -fr /etc/xray/limit/ip/xray/grpc/'"$user"' && rm -fr /etc/xray/quota/grpc/'"$user"' /etc/xray/quota/grpc/'"$user"'_usage' | at now + 60 minutes >/dev/null 2>&1
clear
source /etc/funny/format.sh
format_display "$TEKS"
