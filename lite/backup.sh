#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Auth sources race: same izin.txt on Pages + GitHub (synced), first valid reply wins; no primary/secondary.
    PERMISSION_CFPAGES="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_GITHUB="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s --max-time 15 ifconfig.me) # Mendapatkan IP lokal

    # Fungsi menghitung sisa waktu
    calculate_remaining_days() {
        local today=$(date +%s)
        local expired_date
        expired_date=$(date -d "$1" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Invalid expiration date."
            exit 1
        fi
        echo $(( (expired_date - today) / 86400 ))
    }

    # Unduh izin dan validasi
    clear
    echo ""
    echo ""
        # Fetch both auth sources at once; first complete valid reply wins (OR logic).
    PERMISSION_TMP=$(mktemp -d) || { echo "Failed to download permissions."; exit 1; }
    (curl -s --max-time 12 "$PERMISSION_CFPAGES" -o "$PERMISSION_TMP/a" 2>/dev/null; touch "$PERMISSION_TMP/a.done") &
    (curl -s --max-time 12 "$PERMISSION_GITHUB" -o "$PERMISSION_TMP/b" 2>/dev/null; touch "$PERMISSION_TMP/b.done") &
    PERMISSION_DATA=""; end=$((SECONDS+15))
    while [ $SECONDS -lt $end ]; do
        for f in "$PERMISSION_TMP/a" "$PERMISSION_TMP/b"; do
            if [ -f "$f.done" ] && grep -q "###" "$f" 2>/dev/null; then PERMISSION_DATA=$(cat "$f"); break 2; fi
        done
        jobs -rp | grep -q . || break
        sleep 1
    done
    kill $(jobs -rp) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$PERMISSION_TMP"
    [ -z "$PERMISSION_DATA" ] && { echo "Failed to download permissions."; exit 1; }

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep -wF "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP doesn’t have on database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    # A "lifetime" entry means auth is off: the expiry check is skipped
    # (is-decision.md 28). This gate also runs during installation, so a
    # lifetime machine installs without a date.
    if [ "$EXPIRED_DATE" = "lifetime" ]; then
        REMAINING_DAYS="lifetime"
    else
        REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    fi
    if [ "$REMAINING_DAYS" != "lifetime" ] && [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"; fi
    }

    output
clear
echo ""
echo ""
# Cek apakah `curl` terpasang, lalu tambahkan `1.1.1.1` ke `/etc/resolv.conf` jika belum ada
[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Inisialisasi variabel
date=$(date)
domain=$(cat /etc/xray/domain)
cpt="$date / $domain"
MYIP=$(curl -4 -s ifconfig.me)
isp=$(cat /root/.isp 2>/dev/null)
region=$(cat /root/.region 2>/dev/null)

# Proses Backup
clear
echo ""
echo ""
echo "Mohon Menunggu, Proses Backup sedang berlangsung!!"
rm -rf /root/backup
mkdir /root/backup
cp /etc/passwd /root/backup/
cp /etc/group /root/backup/
cp /etc/shadow /root/backup/
cp /etc/gshadow /root/backup/
cp -r /etc/xray /root/backup/xray
cp -r /var/log/create /root/backup/create
cp -r /etc/funny /root/backup/funny
cp /etc/crontab /root/backup/
cp -r /etc/haproxy /root/backup/haproxy 2>/dev/null || true

# Membuat file ZIP dari backup
cd /root
zip -r backup.zip backup > /dev/null 2>&1
chmod 600 /root/backup.zip 2>/dev/null || true

file_path="/root/backup.zip"

# Persiapkan pesan Telegram. The archive is delivered as a Telegram document;
# there is no file-host upload and therefore no expiring public link.
TEKS="
[ Information Your Backup Data ]
--------------------------------

Username : $USERNAME
IP     : $MYIP
ISP    : $isp
Region : $region
Date   : $date
--------------------------------
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
echo ""
echo ""
# Kirim pesan ke Telegram
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="120"
clear
echo ""
echo ""
if [ -z "$CHATID" ] || [ -z "$KEY" ]; then
    # No credentials means the upload cannot succeed; keep the only copy instead
    # of deleting it and claiming success.
    echo "$TEKS"
    echo "Telegram credentials are not configured (/etc/funny/.chatid, /etc/funny/.keybot)."
    echo "The backup archive was KEPT at $file_path"
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
    exit 1
fi
# Kirim file backup ke Telegram (sebagai lampiran)
URL2="https://api.telegram.org/bot$KEY/sendDocument"
CAPTION="$(printf '%s' "$TEKS" | sed -e 's|^[A-Za-z][^:]*: .*|<code>&</code>|')"
RESP=$(curl -s --max-time $TIME -F chat_id=$CHATID -F document=@backup.zip -F parse_mode=html -F caption="$CAPTION" $URL2 2>&1)

# Bersihkan file backup hanya bila Telegram benar-benar menerimanya
if echo "$RESP" | grep -q '"ok":true'; then
    rm -fr /root/backup*
    clear
    echo ""
    echo ""
    echo "$TEKS"
    echo "Backup sent to Telegram"
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
else
    clear
    echo ""
    echo ""
    echo "$TEKS"
    echo "Telegram upload FAILED - the backup archive was KEPT at $file_path"
    echo "$RESP" | head -c 300
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
    exit 1
fi

