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
# Cek apakah `curl` terpasang, lalu tambahkan `1.1.1.1` ke `/etc/resolv.conf` jika belum ada
[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Inisialisasi variabel
date=$(date)
domain=$(cat /etc/xray/domain)
cpt="$date / $domain"
MYIP=$(curl -4 -s ifconfig.me)

# Proses Backup
clear
echo "Mohon Menunggu, Proses Backup sedang berlangsung!!"
rm -rf /root/backup
mkdir /root/backup
cp /etc/passwd /root/backup/
cp /etc/group /root/backup/
cp /etc/shadow /root/backup/
cp /etc/gshadow /root/backup/
cp -r /etc/xray /root/backup/xray
cp -r /etc/v2ray /root/backup/v2ray
cp -r /var/log/create /root/backup/create
cp -r /etc/funny /root/backup/funny
cp /etc/crontab /root/backup/
cp -r /etc/wireguard /root/backup/wireguard 2>/dev/null || true
cp -r /etc/slowdns /root/backup/slowdns 2>/dev/null || true
cp -r /etc/noobzvpns /root/backup/noobzvpns 2>/dev/null || true
cp -r /etc/ppp /root/backup/ppp 2>/dev/null || true
cp -r /etc/ipsec.d /root/backup/ipsec.d 2>/dev/null || true
cp /etc/ipsec.secrets /root/backup/ 2>/dev/null || true

# Membuat file ZIP dari backup
cd /root
zip -r backup.zip backup > /dev/null 2>&1

# Upload file ZIP ke file.io dan ambil link
file_path="/root/backup.zip"
api_url="https://file.io"
expiry_duration=$((14 * 24 * 60 * 60))
response=$(curl -sL --max-time 60 -F "file=@$file_path" -F "expiry=$expiry_duration" $api_url)
upload_link=$(echo "$response" | jq -r .link 2>/dev/null)
id_link=$(echo "$response" | jq -r .key 2>/dev/null)
# Bug 74: file.io discontinued anonymous uploads (it now returns its landing
# page instead of JSON), and transfer.sh/0x0.st/bashupload are dead or
# disabled. Fall back to working hosts so backups still produce a link.
if [ -z "$upload_link" ] || [ "$upload_link" = "null" ]; then
    response=$(curl -s --max-time 60 -F file=@"$file_path" https://tmpfiles.org/api/v1/upload)
    upload_link=$(echo "$response" | jq -r .data.url 2>/dev/null)
    id_link="tmpfiles.org"
fi
if [ -z "$upload_link" ] || [ "$upload_link" = "null" ]; then
    upload_link=$(curl -s --max-time 60 -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@$file_path" https://litterbox.catbox.moe/resources/internals/api.php)
    id_link="litterbox-72h"
fi
email=$(cat /etc/funny/.email)

# Persiapkan pesan Telegram
TEKS="
[ Information Your Backup Data ]
================================

Email      : $email
Your ID    : $id_link
Your IP    : $MYIP
Link Backup: $upload_link
Date / Domain: $date / $domain
================================
Your File Backup AutoDelete After 7 Days
"

# Cek dan buat file backup.log jika tidak ada
if [ ! -f /etc/funny/backup.log ]; then
    touch /etc/funny/backup.log
    echo "File /etc/funny/backup.log telah dibuat."
else
    echo "File /etc/funny/backup.log sudah ada, melanjutkan perintah selanjutnya."
fi

# Menyimpan Log Backup
echo "$TEKS" >> /etc/funny/backup.log
clear

# Kirim pesan ke Telegram
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
#URL1="https://api.telegram.org/bot$KEY/sendMessage"
#curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEKS&parse_mode=html" $URL1 >/dev/null

# Kirim file backup ke Telegram
URL2="https://api.telegram.org/bot$KEY/sendDocument"
CAPTION="$TEKS"
curl -s --max-time $TIME -F chat_id=$CHATID -F document=@backup.zip -F caption="$CAPTION" $URL2

# Bersihkan file backup setelah selesai
rm -fr /root/backup*

# Output informasi backup ke layar
clear
echo "$TEKS"
echo "Please Save your Link Backup"

