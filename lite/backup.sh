#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
echo ""
echo ""
# Cek apakah `curl` terpasang, lalu tambahkan `1.1.1.1` ke `/etc/resolv.conf` jika belum ada
[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Found 526: never leave the backup IP blank. Probe several sources, accept only
# a valid IPv4, and fall back to the address recorded at install time.
# Found 529: make that validation strict - every octet must be digits and <=255.
is_ipv4() {
    printf '%s\n' "$1" | awk -F. '
        NF != 4 { exit 1 }
        {
            for (i = 1; i <= 4; i++) {
                if ($i !~ /^[0-9]+$/ || $i > 255) exit 1
            }
            exit 0
        }
    '
}

get_public_ipv4() {
    local url ip
    for url in https://ifconfig.me https://ipv4.icanhazip.com https://api.ipify.org https://ipinfo.io/ip; do
        ip=$(curl -4 -fsSL --max-time 8 "$url" 2>/dev/null) || continue
        ip=$(printf '%s' "$ip" | tr -d '[:space:]')
        if is_ipv4 "$ip"; then
            printf '%s\n' "$ip"
            return 0
        fi
    done
    if [ -r /etc/.ip ]; then
        ip=$(tr -d '[:space:]' < /etc/.ip 2>/dev/null)
        if is_ipv4 "$ip"; then
            printf '%s\n' "$ip"
            return 0
        fi
    fi
    return 1
}

# Inisialisasi variabel
date=$(date)
installer_domain=$(cat /etc/xray/installer-domain)
cpt="$date / $installer_domain"
MYIP=$(get_public_ipv4) || MYIP="unknown"
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
# Found 511: version markers are system state, not account data. Do not put
# them in a backup that may be restored onto a newer panel. format.sh stays
# in the archive as a fallback; restore keeps the running copy when present.
rm -f /root/backup/funny/.install-commit \
      /root/backup/funny/.update-commit \
      /root/backup/funny/version
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

