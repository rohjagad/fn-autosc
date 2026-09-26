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

until [[ $user =~ ^[a-z0-9_]+$ && ${client_exists} == '0' && ! -f /var/log/create/xray/split/${user}.log ]]; do
    echo -e "
\033[38;2;255;0;0m-\033[38;2;255;54;0m-\033[38;2;255;109;0m-\033[38;2;255;163;0m-\033[38;2;255;218;0m-\033[38;2;237;255;0m-\033[38;2;183;255;0m-\033[38;2;128;255;0m-\033[38;2;73;255;0m-\033[38;2;19;255;0m-\033[38;2;0;255;36m-\033[38;2;0;255;91m-\033[38;2;0;255;145m-\033[38;2;0;255;200m-\033[38;2;0;255;255m-\033[38;2;0;201;255m-\033[38;2;0;146;255m-\033[38;2;0;92;255m-\033[38;2;0;37;255m-\033[38;2;18;0;255m-\033[38;2;72;0;255m-\033[38;2;127;0;255m-\033[38;2;182;0;255m-\033[38;2;236;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;164m-\033[38;2;255;0;110m-\033[38;2;255;0;55m-\033[38;2;255;0;0m-\033[0m
   \033[1;33mCreate VMess Split HTTP\033[0m
\033[38;2;255;0;0m-\033[38;2;255;54;0m-\033[38;2;255;109;0m-\033[38;2;255;163;0m-\033[38;2;255;218;0m-\033[38;2;237;255;0m-\033[38;2;183;255;0m-\033[38;2;128;255;0m-\033[38;2;73;255;0m-\033[38;2;19;255;0m-\033[38;2;0;255;36m-\033[38;2;0;255;91m-\033[38;2;0;255;145m-\033[38;2;0;255;200m-\033[38;2;0;255;255m-\033[38;2;0;201;255m-\033[38;2;0;146;255m-\033[38;2;0;92;255m-\033[38;2;0;37;255m-\033[38;2;18;0;255m-\033[38;2;72;0;255m-\033[38;2;127;0;255m-\033[38;2;182;0;255m-\033[38;2;236;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;164m-\033[38;2;255;0;110m-\033[38;2;255;0;55m-\033[38;2;255;0;0m-\033[0m
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

    client_exists=$(grep -w $user /etc/xray/json/split.json | wc -l)

    if [[ ${client_exists} == '1' ]]; then
        clear
        echo -e "\033[0;31mUsername already exists.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/split/${user}.log ]]; then
        clear
        echo -e "\033[0;31mUsername already exists in log file.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/split/${user}.locked ]]; then
        clear
        echo -e "\033[0;31mUsername already exists in locked file.\033[0m"
        continue
    fi
done
    echo ""
    echo -e "\033[38;5;208m0 not allowed\033[0m"
    read -p "Limit Ip: " ip
    while ! [[ "$ip" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Limit Ip: " ip || exit 1
    done
    read -p "Limit Quota (GBs): " quota
    while ! [[ "$quota" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Limit Quota (GBs): " quota || exit 1
    done
    read -p "Active Time (days): " masaaktif
    while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Active Time (days): " masaaktif || exit 1
    done
    read -p "Input UUID (Empty Default): " uuid

# Validasi UUID
if [[ "$uuid" =~ [[:space:]] || -z "$uuid" ]]; then
    echo "UUID empty or contains spaces, generating new UUID..."
    uuid=$(xray uuid)
    echo "New UUID: $uuid"
else
    echo "Using provided UUID: $uuid"
fi
clear

# Limit Quota
if [[ $quota -gt 0 ]]; then
echo -e "$[$quota * 1024 * 1024 * 1024]" > /etc/xray/quota/split/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/split/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%y-%m-%d"`

# Menambahkan akun pada json
sed -i '/#vmess$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","alterid": 0,"email": "'""$user""'","level": 0}/}' /etc/xray/json/split.json

# Me Restart Service
systemctl daemon-reload
systemctl restart xray@split
systemctl restart quota-split

# Konfigurasi Json WS TLS
acs=`cat<<eof
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "443",
"id": "${uuid}",
"aid": "0",
"net": "splithttp",
"path": "/vmspl",
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
"net": "splithttp",
"path": "/vmspl",
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
======================
   VMess Split HTTP
======================

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Protokol: Vmess
======================
     Limit Detail

Limit IP: $ip
Quota   : $quota GB
======================
  Detail Port split

TLS: 443, 2053, 2083, 2087, 2096
NoneTLS: 80, 8880, 2052, 2082, 2095
======================
AlterID: 0
Path   : /vmspl
Network: Split HTTP
Alpn   : - [ None ]
Decrypt: auto
======================
Link TLS : $vmesslink1
======================
Link None: $vmesslink2
======================
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/split/${user}.log
clear
source /etc/funny/format.sh
format_display "$TEKS"
