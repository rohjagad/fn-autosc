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

until [[ $user =~ ^[a-z0-9_]+$ && ${client_exists} == '0' && ! -f /var/log/create/xray/ws/${user}.log ]]; do
    echo -e "
\033[38;2;255;0;0m-\033[38;2;255;56;0m-\033[38;2;255;113;0m-\033[38;2;255;170;0m-\033[38;2;255;226;0m-\033[38;2;227;255;0m-\033[38;2;170;255;0m-\033[38;2;114;255;0m-\033[38;2;57;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;56m-\033[38;2;0;255;113m-\033[38;2;0;255;170m-\033[38;2;0;255;226m-\033[38;2;0;227;255m-\033[38;2;0;170;255m-\033[38;2;0;114;255m-\033[38;2;0;57;255m-\033[38;2;0;0;255m-\033[38;2;56;0;255m-\033[38;2;113;0;255m-\033[38;2;170;0;255m-\033[38;2;226;0;255m-\033[38;2;255;0;227m-\033[38;2;255;0;170m-\033[38;2;255;0;114m-\033[38;2;255;0;57m-\033[38;2;255;0;0m-\033[0m
       \033[1;33mCreate VMess WS\033[0m
\033[38;2;255;0;0m-\033[38;2;255;56;0m-\033[38;2;255;113;0m-\033[38;2;255;170;0m-\033[38;2;255;226;0m-\033[38;2;227;255;0m-\033[38;2;170;255;0m-\033[38;2;114;255;0m-\033[38;2;57;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;56m-\033[38;2;0;255;113m-\033[38;2;0;255;170m-\033[38;2;0;255;226m-\033[38;2;0;227;255m-\033[38;2;0;170;255m-\033[38;2;0;114;255m-\033[38;2;0;57;255m-\033[38;2;0;0;255m-\033[38;2;56;0;255m-\033[38;2;113;0;255m-\033[38;2;170;0;255m-\033[38;2;226;0;255m-\033[38;2;255;0;227m-\033[38;2;255;0;170m-\033[38;2;255;0;114m-\033[38;2;255;0;57m-\033[38;2;255;0;0m-\033[0m
"
    read -p "Username: " user
    if [[ -z "$user" ]]; then
        clear
        echo -e "\033[0;31mUsername cannot be empty.\033[0m"
        continue
    fi

    if [[ $user =~ [A-Z] || $user =~ [[:space:]] ]]; then
        clear
        echo -e "\033[0;31mUsername cannot contain uppercase letters or spaces.\033[0m"
        continue
    fi

    if [[ $user =~ [^a-z0-9_] ]]; then
        clear
        echo -e "Username can only contain lowercase letters, numbers, and underscores."
        continue
    fi

    client_exists=$(grep -w $user /etc/v2ray/config.json | wc -l)

    if [[ ${client_exists} == '1' ]]; then
        clear
        echo -e "\033[0;31mUsername already exists.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/ws/${user}.log ]]; then
        clear
        echo -e "\033[0;31mUsername already exists in log file.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/ws/${user}.locked ]]; then
        clear
        echo -e "\033[0;31mUsername already exists in locked file.\033[0m"
        continue
    fi
done
    read -p "Limit Ip: " ip
    read -p "Limit Quota: " quota
    read -p "Active Time: " masaaktif
    read -p "Input UUID (Empty Default): " uuid

# Validasi UUID
if [[ "$uuid" =~ [[:space:]] || -z "$uuid" ]]; then
    echo "UUID empty or contains spaces, generating new UUID..."
    uuid=$(xray uuid)
    echo "New UUID: $uuid"
else
    echo "Using provided UUID: $uuid"
fi

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

# Menambahkan akun pada json
sed -i '/#vmess$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","alterid": 0,"email": "'""$user""'"}/}' /etc/v2ray/config.json

# Me Restart Service
systemctl daemon-reload
systemctl restart v2ray
systemctl restart quota-ws

# Konfigurasi Json WS TLS
acs=`cat<<eof
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "443",
"id": "${uuid}",
"aid": "0",
"net": "ws",
"path": "/vmess",
"type": "none",
"host": "${domain}",
"tls": "tls"
}
eof`

# Konfigurasi Json WS NoneTLS
ask=`cat<<eof
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "80",
"id": "${uuid}",
"aid": "0",
"net": "ws",
"path": "/worryfree",
"type": "none",
"host": "${domain}",
"tls": "none"
}
eof`

# Membuat Menjadi Link Untuk Client
vmesslink1="vmess://$(echo $acs | base64 -w 0)"
vmesslink2="vmess://$(echo $ask | base64 -w 0)"

clear
TEKS="
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
     \033[1;33mXray VMess WS\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Protokol: Vmess
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
     Limit Detail

Limit IP: $ip
Quota   : $quota GB
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
   Detail Port Ws

TLS: 443, 2053, 2083, 2087, 2096
NoneTLS: 80, 8880, 2052, 2082, 2095
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
AlterID: 0
Path   : /vmess (TLS), /worryfree (NoneTLS)
Network: WebSocket
Alpn   : - [ None ]
Decrypt: auto
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink TLS : $vmesslink1\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink None: $vmesslink2\033[0m
\033[38;2;255;0;0m-\033[38;2;255;69;0m-\033[38;2;255;139;0m-\033[38;2;255;208;0m-\033[38;2;232;255;0m-\033[38;2;163;255;0m-\033[38;2;93;255;0m-\033[38;2;24;255;0m-\033[38;2;0;255;46m-\033[38;2;0;255;115m-\033[38;2;0;255;185m-\033[38;2;0;255;255m-\033[38;2;0;186;255m-\033[38;2;0;116;255m-\033[38;2;0;47;255m-\033[38;2;23;0;255m-\033[38;2;92;0;255m-\033[38;2;162;0;255m-\033[38;2;231;0;255m-\033[38;2;255;0;209m-\033[38;2;255;0;140m-\033[38;2;255;0;70m-\033[38;2;255;0;0m-\033[0m
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/ws/${user}.log
clear
source /etc/funny/format.sh
format_display "$TEKS"
