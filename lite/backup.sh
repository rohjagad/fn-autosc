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

# Membuat file ZIP dari backup
cd /root
zip -r backup.zip backup > /dev/null 2>&1

file_path="/root/backup.zip"

# Persiapkan pesan Telegram. The archive is delivered as a Telegram document;
# there is no file-host upload and therefore no expiring public link.
TEKS="
[ Information Your Backup Data ]
================================

Domain : $domain
IP     : $MYIP
Date   : $date
================================
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
# Kirim file backup ke Telegram (sebagai lampiran)
URL2="https://api.telegram.org/bot$KEY/sendDocument"
CAPTION="$TEKS"
curl -s --max-time $TIME -F chat_id=$CHATID -F document=@backup.zip -F caption="$CAPTION" $URL2

# Bersihkan file backup setelah selesai
rm -fr /root/backup*

# Output informasi backup ke layar
clear
echo "$TEKS"
echo "Backup sent to Telegram"

