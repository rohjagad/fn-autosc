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

until [[ $user =~ ^[a-z0-9_]+$ && ${client_exists} == '0' && ! -f /var/log/create/xray/http/${user}.log ]]; do
    echo -e "
\033[38;2;255;0;0m-\033[38;2;255;51;0m-\033[38;2;255;102;0m-\033[38;2;255;153;0m-\033[38;2;255;204;0m-\033[38;2;255;255;0m-\033[38;2;204;255;0m-\033[38;2;153;255;0m-\033[38;2;102;255;0m-\033[38;2;51;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;51m-\033[38;2;0;255;102m-\033[38;2;0;255;153m-\033[38;2;0;255;204m-\033[38;2;0;255;255m-\033[38;2;0;204;255m-\033[38;2;0;153;255m-\033[38;2;0;102;255m-\033[38;2;0;51;255m-\033[38;2;0;0;255m-\033[38;2;51;0;255m-\033[38;2;102;0;255m-\033[38;2;153;0;255m-\033[38;2;204;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;204m-\033[38;2;255;0;153m-\033[38;2;255;0;102m-\033[38;2;255;0;51m-\033[38;2;255;0;0m-\033[0m
   \033[1;33mCreate VLess HTTP Upgrade\033[0m
\033[38;2;255;0;0m-\033[38;2;255;51;0m-\033[38;2;255;102;0m-\033[38;2;255;153;0m-\033[38;2;255;204;0m-\033[38;2;255;255;0m-\033[38;2;204;255;0m-\033[38;2;153;255;0m-\033[38;2;102;255;0m-\033[38;2;51;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;51m-\033[38;2;0;255;102m-\033[38;2;0;255;153m-\033[38;2;0;255;204m-\033[38;2;0;255;255m-\033[38;2;0;204;255m-\033[38;2;0;153;255m-\033[38;2;0;102;255m-\033[38;2;0;51;255m-\033[38;2;0;0;255m-\033[38;2;51;0;255m-\033[38;2;102;0;255m-\033[38;2;153;0;255m-\033[38;2;204;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;204m-\033[38;2;255;0;153m-\033[38;2;255;0;102m-\033[38;2;255;0;51m-\033[38;2;255;0;0m-\033[0m
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

    client_exists=$(grep -w $user /etc/xray/json/upgrade.json | wc -l)

    if [[ ${client_exists} == '1' ]]; then
        clear
        echo -e "\033[0;31mUsername already exists.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/http/${user}.log ]]; then
        clear
        echo -e "\033[0;31mUsername already exists in log file.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/http/${user}.locked ]]; then
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

# Limit Quota
if [[ $quota -gt 0 ]]; then
echo -e "$[$quota * 1024 * 1024 * 1024]" > /etc/xray/quota/http/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/http/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%y-%m-%d"`

# Menambahkan akun pada json
sed -i '/#vless$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","email": "'""$user""'"}/}' /etc/xray/json/upgrade.json

# Restart Service
systemctl daemon-reload
systemctl restart xray@upgrade
systemctl restart quota-http

# Konfigurasi Vless http TLS
vlesslink1="vless://${uuid}@${domain}:443?path=/imam&security=tls&encryption=none&host=${domain}&type=httpupgrade&sni=${domain}#${user}"

# Konfigurasi Vless http NoneTLS
vlesslink2="vless://${uuid}@${domain}:80?path=/imam&security=none&encryption=none&host=${domain}&type=httpupgrade#${user}"

TEKS="
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m
   \033[1;33mVLess HTTP Upgrade\033[0m
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Protokol: Vless
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m
     Limit Detail

Limit IP: $ip
Quota   : $quota GB
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m

TLS: 443, 2053, 2083, 2087, 2096
Path: /imam
NoneTLS: 80, 8880, 2052, 2082, 2095
Network: HTTP Upgrade
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink TLS : $vlesslink1\033[0m
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m
\033[1;33mLink None: $vlesslink2\033[0m
\033[38;2;255;0;0m-\033[38;2;255;66;0m-\033[38;2;255;133;0m-\033[38;2;255;199;0m-\033[38;2;244;255;0m-\033[38;2;178;255;0m-\033[38;2;111;255;0m-\033[38;2;45;255;0m-\033[38;2;0;255;22m-\033[38;2;0;255;88m-\033[38;2;0;255;155m-\033[38;2;0;255;221m-\033[38;2;0;222;255m-\033[38;2;0;156;255m-\033[38;2;0;89;255m-\033[38;2;0;23;255m-\033[38;2;44;0;255m-\033[38;2;110;0;255m-\033[38;2;177;0;255m-\033[38;2;243;0;255m-\033[38;2;255;0;200m-\033[38;2;255;0;134m-\033[38;2;255;0;67m-\033[38;2;255;0;0m-\033[0m
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/http/${user}.log
clear
source /etc/funny/format.sh
format_display "$TEKS"
