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

# Function Send Log
send_log() {
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

        TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>⚠️ X-RAY DELETED ACOUNT ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️  Date     :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$name</code>
<b>📌 Expired  :</b> <b>$exp2</b>
<b>🛡️  Protokol :</b> <b>$protokol2</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah di unlock oleh owner dan dapat digunakan kembali."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
locked_files=$(ls /var/log/create/xray/split/*.locked)

# Mengecek apakah ada file terkunci
if [ $(echo "$locked_files" | wc -l) -gt 1 ]; then
    clear
    echo -e "==========================\n<= Menu Unlock X-Ray WS =>\n=========================="

    # Loop untuk menampilkan semua akun terkunci
    for file in $locked_files; do
        username=$(basename "$file" .locked)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep "Protokol:" "$file" | awk '{print $2}')
        
        # Menampilkan informasi akun
        echo -e "Username: $username"
        echo -e "Status  : Locked"
        echo -e "UUID    : $uid"
        echo -e "Expired : $exp"
        echo -e "Protokol: $protokol"
        echo -e "=========================="
    done
    
    echo -e "Press CTRL + C to Exit"
    read -p "Input Username to Unlock: " name
else
    # Jika hanya ada satu akun terkunci
    if [ -n "$locked_files" ]; then
        name=$(basename "$locked_files" .locked)
    else
        clear
        echo "Tidak ada akun yang terkunci."
        exit 1
    fi
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/split/${name}.locked | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/split/${name}.locked | awk '{print $3}')
protokol2=$(grep "Protokol:" /var/log/create/xray/split/${name}.locked | awk '{print $2}')

clear

echo -e "
Detail Unlock X-Ray WS
======================

Date: $(date)
Username: $name
Expired on: $exp2
UUID: $uuid
Protokol: $protokol2
Status: Unlock
======================"

# Konfirmasi dari pengguna sebelum melakukan unlock
read -p "Apakah Anda yakin ingin unlock akun ini? (y/n): " confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Logika melakukan unlock
    if [ "$protokol2" == "Vmess" ]; then
        sed -i '/#vmess$/a\### '"$name $exp2"'\
        },{"id": "'""$uuid""'","alterid": 0,"email": "'""$name""'"' /etc/xray/json/split.json
    elif [ "$protokol2" == "Vless" ]; then
        sed -i '/#vless$/a\### '"$name $exp2"'\
        },{"id": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/split.json
    elif [ "$protokol2" == "Trojan" ]; then
        sed -i '/#trojan$/a\### '"$name $exp2"'\
        },{"password": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/split.json
    else
        echo "Protokol tidak dikenal"
    fi

    mv /var/log/create/xray/split/${name}.locked /var/log/create/xray/split/${name}.log
     systemctl daemon-reload
     systemctl restart xray@split
    # Send Notif Telegram
    send_log

    clear
    echo -e "
    Detail Unlock X-Ray WS
    ======================

    Date: $(date)
    Username: $name
    Expired on: $exp2
    UUID: $uuid
    Protokol: $protokol2
    Status: Unlock
    =======================
    "
else
    echo "Proses unlock dibatalkan."
fi