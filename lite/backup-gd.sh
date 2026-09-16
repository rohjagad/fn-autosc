#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohfn-autosc-auth/1.23/izin.txt"
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
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
#IP=$(wget -qO- ipinfo.io/ip);
IP=$(curl -s ifconfig.me);
date=$(date +"%Y-%m-%d")
clear
email=$(cat /etc/funny/.email)
if [[ "$email" = "" ]]; then
  echo -e "\e[0;37m Enter Your Email To Receive Backup"
  read -rp " Email: " -e email
  cat <<EOF>>/etc/funny/.email
$email
EOF
fi
domain=$(cat /etc/xray/domain)
clear
mkdir -p /root/backup
sleep 1
echo Start Backup
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
cd /root

zip -r Backup-$date.zip backup > /dev/null 2>&1
rclone copy /root/Backup-$date.zip dr:backup/
url=$(rclone link dr:backup/Backup-$date.zip)
id=(`echo $url | grep '^https' | cut -d'=' -f2`)
link="https://drive.google.com/u/4/uc?id=${id}&export=download"
echo -e "
Detail Backup
==================================
ID VPS        : $id
IP VPS        : $IP
Domain.       : $domain
Link Backup   : $link
Date Backup   : $date
==================================
" | mail -s "VPS Backup Data | $date" $email
clear
rm -fr www*
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL1="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEKS&parse_mode=html" $URL1 >/dev/null
URL2="https://api.telegram.org/bot$KEY/sendDocument"
cpt="$(date) / $domain"
CAPTION="${cpt}"
opwares="Detail Backup
==================================
Email         : $email
ID VPS        : $id
IP VPS        : $IP
Domain.       : $domain
Link Backup   : $link
Date Backup   : $date
=================================="
curl -s --max-time $TIME -F chat_id=$CHATID -F document=@Backup-$date.zip -F caption="$opwares" $URL2 >/dev/null
clear
echo -e "
Detail Backup
==================================
Email         : $email
IP VPS        : $IP
Link Backup   : $link
Date Backup   : $date
==================================
"
rm -rf /root/backup
rm -r /root/Backup-$date.zip
echo -e "\e[0;37m Done!"
echo ""
echo -e "\e[0;37m Please Check Your Email Now!"
echo ""
read -sp " Press ENTER to go back"
echo ""
menu
