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
\033[38;2;255;0;0m-\033[38;2;255;52;0m-\033[38;2;255;105;0m-\033[38;2;255;158;0m-\033[38;2;255;211;0m-\033[38;2;247;255;0m-\033[38;2;194;255;0m-\033[38;2;141;255;0m-\033[38;2;88;255;0m-\033[38;2;36;255;0m-\033[38;2;0;255;17m-\033[38;2;0;255;70m-\033[38;2;0;255;123m-\033[38;2;0;255;175m-\033[38;2;0;255;228m-\033[38;2;0;229;255m-\033[38;2;0;176;255m-\033[38;2;0;124;255m-\033[38;2;0;71;255m-\033[38;2;0;18;255m-\033[38;2;35;0;255m-\033[38;2;87;0;255m-\033[38;2;140;0;255m-\033[38;2;193;0;255m-\033[38;2;246;0;255m-\033[38;2;255;0;212m-\033[38;2;255;0;159m-\033[38;2;255;0;106m-\033[38;2;255;0;53m-\033[38;2;255;0;0m-\033[0m
  \033[1;33mCreate Trojan Split HTTP\033[0m
\033[38;2;255;0;0m-\033[38;2;255;52;0m-\033[38;2;255;105;0m-\033[38;2;255;158;0m-\033[38;2;255;211;0m-\033[38;2;247;255;0m-\033[38;2;194;255;0m-\033[38;2;141;255;0m-\033[38;2;88;255;0m-\033[38;2;36;255;0m-\033[38;2;0;255;17m-\033[38;2;0;255;70m-\033[38;2;0;255;123m-\033[38;2;0;255;175m-\033[38;2;0;255;228m-\033[38;2;0;229;255m-\033[38;2;0;176;255m-\033[38;2;0;124;255m-\033[38;2;0;71;255m-\033[38;2;0;18;255m-\033[38;2;35;0;255m-\033[38;2;87;0;255m-\033[38;2;140;0;255m-\033[38;2;193;0;255m-\033[38;2;246;0;255m-\033[38;2;255;0;212m-\033[38;2;255;0;159m-\033[38;2;255;0;106m-\033[38;2;255;0;53m-\033[38;2;255;0;0m-\033[0m
"
    read -p $'\033[96;1mUsername: \033[0m' user
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
    read -p $'\033[96;1mLimit Ip: \033[0m' ip
    read -p $'\033[96;1mLimit Quota: \033[0m' quota
    read -p $'\033[96;1mActive Time: \033[0m' masaaktif
    read -p $'\033[96;1mInput UUID (Empty Default): \033[0m' uuid

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

# Menambahkan Akun di Database
sed -i '/#trojan$/{n;s/}/},\n### '"$user $exp"'\n{"password": "'""$uuid""'","email": "'""$user""'"}/}' /etc/xray/json/split.json

# Restart Service
systemctl daemon-reload
systemctl restart xray@split
systemctl restart quota-split

# Konfigurasi Trojan split TLS
link1="trojan://${uuid}@${domain}:443?path=/splittr&security=tls&host=${domain}&type=splithttp&sni=${domain}#${user}"

# Konfigurasi Trojan split NonTLS
link2="trojan://${uuid}@${domain}:80?path=/splittr&security=none&host=${domain}&type=splithttp#${user}"

TEKS="
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
   \033[1;33mTrojan Split HTTP\033[0m
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Limit IP: $ip
Quota   : $quota GB
Protokol: Trojan
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m

Path: /splittr
Network: Split HTTP
Port TLS: 443, 2053, 2083, 2087, 2096
Port None: 80, 8880, 2052, 2082, 2095
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink TLS : $link1\033[0m
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink None: $link2\033[0m
\033[38;2;255;0;0m-\033[38;2;255;72;0m-\033[38;2;255;145;0m-\033[38;2;255;218;0m-\033[38;2;219;255;0m-\033[38;2;146;255;0m-\033[38;2;73;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;72m-\033[38;2;0;255;145m-\033[38;2;0;255;218m-\033[38;2;0;219;255m-\033[38;2;0;146;255m-\033[38;2;0;73;255m-\033[38;2;0;0;255m-\033[38;2;72;0;255m-\033[38;2;145;0;255m-\033[38;2;218;0;255m-\033[38;2;255;0;219m-\033[38;2;255;0;146m-\033[38;2;255;0;73m-\033[38;2;255;0;0m-\033[0m
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/split/${user}.log
clear
source /etc/funny/format.sh
format_display "$TEKS"
