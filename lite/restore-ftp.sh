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

# Detail Informasi
ip4=$(curl -sS ipv4.icanhazip.com)
ip6=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
cd /root
# Check both upload and root locations
if ls /var/www/uploads/*.zip 1>/dev/null 2>&1; then
    mv /var/www/uploads/*.zip /root/backup.zip
elif ls /root/*backup*.zip 1>/dev/null 2>&1; then
    mv /root/*backup*.zip /root/backup.zip
fi
file="backup.zip"
if [ -f "$file" ]; then
echo "$file found, continuing..."
sleep 2
clear
unzip backup.zip
rm -f backup.zip
sleep 1
echo "Backing up data"
cd /root/backup
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp crontab /etc/
cp -r xray /etc/
cp -r funny /etc/
cp -r create /var/log/
cp -r wireguard /etc/ 2>/dev/null || true
cp -r slowdns /etc/ 2>/dev/null || true
cp -r noobzvpns /etc/ 2>/dev/null || true
cp -r ppp /etc/ 2>/dev/null || true
cp -r ipsec.d /etc/ 2>/dev/null || true
cp ipsec.secrets /etc/ 2>/dev/null || true
clear
cd
rm -rf /root/backup
rm -f backup.zip
clear
systemctl daemon-reload
systemctl restart ssh
systemctl restart xray@ws
systemctl restart xray@grpc
systemctl restart xray@split
systemctl restart xray@upgrade
systemctl restart nginx
systemctl restart cron
clear
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "SUCCESSFULL RESTORE YOUR VPS"
echo -e "Please Save The Following Data"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Your VPS IP : $ip"
echo -e "DOMAIN      : $domain"
echo -e "DATE        : $date"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Error: File $file Not Found"
fi