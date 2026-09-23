#!/bin/bash
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
cp passwd /etc/ >/dev/null 2>&1
cp group /etc/ >/dev/null 2>&1
cp shadow /etc/ >/dev/null 2>&1
cp gshadow /etc/ >/dev/null 2>&1
cp crontab /etc/ >/dev/null 2>&1
cp -r xray /etc/ >/dev/null 2>&1
cp -r v2ray /etc/ >/dev/null 2>&1
cp -r funny /etc/ >/dev/null 2>&1
cp -r create /var/log/ >/dev/null 2>&1
cp -r wireguard /etc/ >/dev/null 2>&1 || true
cp -r slowdns /etc/ >/dev/null 2>&1 || true
cp -r noobzvpns /etc/ >/dev/null 2>&1 || true
cp -r ppp /etc/ >/dev/null 2>&1 || true
cp -r ipsec.d /etc/ >/dev/null 2>&1 || true
cp ipsec.secrets /etc/ >/dev/null 2>&1 || true
clear
cd
rm -rf /root/backup
rm -f backup.zip
clear
systemctl daemon-reload >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart v2ray >/dev/null 2>&1
systemctl restart xray@grpc >/dev/null 2>&1
systemctl restart xray@split >/dev/null 2>&1
systemctl restart xray@upgrade >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
systemctl restart cron >/dev/null 2>&1
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
