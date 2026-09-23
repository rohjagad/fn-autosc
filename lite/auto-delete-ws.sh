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

# Variabel untuk Telegram bot
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Daftar pengguna dari konfigurasi Xray (ambil username dari file JSON)
users=$(grep '^###' /etc/v2ray/config.json | cut -d ' ' -f 2 | sort | uniq)

# Daftar pengguna yang terkunci (cek file dengan ekstensi .locked)
userlock=$(ls /var/log/create/xray/ws/ | grep '.locked$' | sed 's/\.locked$//')

# Variabel untuk mencatat file yang dihapus
deleted_users=""

# Cek apakah ada file log yang sesuai dengan pola /var/log/create/xray/ws/*.log
log_files=$(ls /var/log/create/xray/ws/*.log 2>/dev/null)

if [ -z "$log_files" ]; then
    echo "Tidak ada file log yang ditemukan untuk diproses."
else
    # Perulangan untuk setiap file pengguna di /var/log/create/xray/ws/
    for file in /var/log/create/xray/ws/*.log; do
        user=$(basename "$file" .log)  # Mendapatkan nama pengguna dari nama file

        # Debugging: Tampilkan nama pengguna dan file yang sedang diproses
        echo "Memeriksa file: $file"

        # Periksa jika pengguna terkunci
        if echo "$userlock" | grep -q "^$user$"; then
            echo "Pengguna $user terkunci, file log tidak akan dihapus."
            continue
        fi

        # Validasi apakah pengguna ada di daftar `users` (JSON)
        if echo "$users" | grep -q "^$user$"; then
            echo "Pengguna $user ada di database JSON, tidak ada file yang dihapus."
            continue
        fi

        # Jika pengguna tidak terdaftar di JSON dan tidak terkunci, hapus file terkait
        echo "Menghapus data untuk pengguna $user..."
        rm -f /var/log/create/xray/ws/${user}.log
        rm -f /etc/xray/quota/ws/$user*
        rm -f /etc/xray/limit/ip/xray/ws/$user

        # Tambahkan nama pengguna ke daftar yang dihapus
        deleted_users+="$user "
    done

    # Restart layanan Xray setelah penghapusan
    echo "Restarting Xray service..."
    systemctl daemon-reload
    systemctl restart v2ray
fi

# Kirim notifikasi hanya jika ada pengguna yang dihapus
if [ -n "$deleted_users" ]; then
    TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>⚠️ X-RAY WS Clear Log ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️ Date      :</b> <code>$DATE</code>
<b>📌 Status   :</b> <b>Success Clear Log</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>👤 Pengguna Dihapus:</b> <code>$deleted_users</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Menghapus Log Semua akun yang tidak tersedia didalam database Server.
"
    # Kirim notifikasi ke Telegram
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
else
    echo "Tidak ada pengguna yang dihapus. Notifikasi tidak dikirim."
fi