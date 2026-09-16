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
domain=$(cat /etc/xray/domain)
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
clear

until [[ $user =~ ^[a-z0-9_]+$ && ${client_exists} == '0' && ! -f /var/log/create/xray/grpc/${user}.log ]]; do
    echo -e "
════════════════════════════
<=   Create Trojan gRPC   =>
════════════════════════════
"
    read -p "Username: " user
    if [[ -z "$user" ]]; then
        clear
        echo -e "Username failed: tidak boleh kosong."
        continue
    fi

    if [[ $user =~ [A-Z] || $user =~ [[:space:]] ]]; then
        clear
        echo -e "Username failed: tidak boleh menggunakan huruf kapital atau spasi."
        continue
    fi

    if [[ $user =~ [^a-z0-9_] ]]; then
        clear
        echo -e "Username failed: hanya boleh menggunakan huruf kecil, angka, dan underscore."
        continue
    fi

    client_exists=$(grep -w $user /etc/xray/json/grpc.json | wc -l)

    if [[ ${client_exists} == '1' ]]; then
        clear
        echo -e "Username already exists."
        continue
    fi

    if [[ -f /var/log/create/xray/grpc/${user}.log ]]; then
        clear
        echo -e "Username already exists in log file."
        continue
    fi

    if [[ -f /var/log/create/xray/grpc/${user}.locked ]]; then
        clear
        echo -e "Username already exists in locked file."
        continue
    fi
done
    read -p "Limit Ip: " ip
    read -p "Limit Quota: " quota
    read -p "Active Time: " masaaktif
    read -p "Input UUID (Empty Default): " uuid

# Validasi UUID
if [[ "$uuid" =~ [[:space:]] || -z "$uuid" ]]; then
    echo "UUID kosong atau mengandung spasi, membuat UUID baru..."
    uuid=$(xray uuid)
    echo "UUID baru: $uuid"
else
    echo "Menggunakan UUID yang diberikan: $uuid"
fi

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

# Menambahkan Akun di Database
sed -i '/#trojan$/a\### '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/json/grpc.json

# Restart Service
systemctl daemon-reload
systemctl restart xray@grpc
systemctl restart quota-grpc

# Konfigurasi Trojan gRPC TLS
link1="trojan://${uuid}@${domain}:443?mode=gun&security=tls&authority=${domain}&type=grpc&serviceName=trojan-grpc&sni=${domain}#user"

TEKS="
=======================
<= X-RAY Trojan gRPC =>
=======================

Remarks : $user
Domain  : $domain
UUID    : $uuid
Expired : $exp
Limit IP: $ip
Quota   : $quota GB
Protokol: Trojan
=======================

Service Name: trojan-grpc
Network: gRPC GUN
Port gRPC: 443, 2053, 2083, 2087, 2096
=======================
Link TLS : $link1
=======================
"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL >/dev/null 2>&1
echo -e "$TEKS" > /var/log/create/xray/grpc/${user}.log
clear
echo -e "$TEKS"
