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

# Function Send Log
send_log() {
    CHATID=$(cat /etc/funny/.chatid)
    KEY=$(cat /etc/funny/.keybot)
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    TIME="10"
    DATE=$(date +"%Y-%m-%d %H:%M:%S")

    TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>⚠️ X-RAY gRPC LOCKED ACOUNT ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️  Date     :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$name</code>
<b>📌 Expired  :</b> <b>$exp2</b>
<b>🛡️  Protokol :</b> <b>$protokol2</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah di locked oleh owner dan tidak dapat digunakan."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
locked_files=$(ls /var/log/create/xray/grpc/*.log)

# Mengecek apakah ada file terkunci
if [ $(echo "$locked_files" | wc -l) -gt 0 ]; then
    clear
    echo -e "==========================\n  Locked X-Ray gRPC Menu\n=========================="

    # Loop untuk menampilkan semua akun terkunci
    for file in $locked_files; do
        username=$(basename "$file" .log)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep "Protokol:" "$file" | awk '{print $2}')
        
        # Menampilkan informasi akun terkunci
        echo -e "Username: $username"
        echo -e "Status  : Unlock"
        echo -e "UUID    : $uid"
        echo -e "Expired : $exp"
        echo -e "Protokol: $protokol"
        echo -e "=========================="
    done
    
    # Meminta input username dari pengguna
    read -p "Input Username to Locked: " name
else
    clear
    echo "Tidak ada akun yang terbuka."
    exit 1
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/grpc/${name}.log | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/grpc/${name}.log | awk '{print $3}')
protokol2=$(grep "Protokol:" /var/log/create/xray/grpc/${name}.log | awk '{print $2}')

clear

echo -e "
Detail Locked X-Ray gRPC
======================

Date: $(date)
Username: $name
Expired on: $exp2
UUID: $uuid
Protokol: $protokol2
Status: Locked
======================"

# Langsung lakukan unlock jika username valid
if [ "$protokol2" == "Vmess" ]; then
    sed -i '/#vmess$/a\### '"$name $exp2"'\
    },{"id": "'""$uuid""'","alterid": 0,"email": "'""$name""'"' /etc/xray/json/grpc.json
elif [ "$protokol2" == "Vless" ]; then
    sed -i '/#vless$/a\### '"$name $exp2"'\
    },{"id": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/grpc.json
elif [ "$protokol2" == "Trojan" ]; then
    sed -i '/#trojan$/a\### '"$name $exp2"'\
    },{"password": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/grpc.json
else
    echo "Protokol tidak dikenal"
fi

    exp=$(grep -wE "^### $name" "/etc/xray/json/grpc.json" | cut -d ' ' -f 3 | sort | uniq)
    sed -i "/### $user $exp/ {N;d}" /etc/xray/json/grpc.json
mv /var/log/create/xray/grpc/${name}.log /var/log/create/xray/grpc/${name}.locked
systemctl daemon-reload
systemctl restart xray@grpc
# Send Notif Telegram
send_log

clear
echo -e "
Detail Locked X-Ray gRPC
======================

Date: $(date)
Username: $name
Expired on: $exp2
UUID: $uuid
Protokol: $protokol2
Status: Locked
======================
"
