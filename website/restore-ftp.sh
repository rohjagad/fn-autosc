#!/bin/bash
# Detail Informasi
ip6=$(curl -sS ipv4.icanhazip.com)
ip4=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
cd /root
mv /var/www/uploads/*.zip /root/backup.zip
file="backup.zip"
if [ -f "$file" ]; then
echo "$file ditemukan, melanjutkan proses..."
sleep 2
clear
unzip backup.zip
rm -f backup.zip
sleep 1
echo "Tengah Melakukan Backup Data"
cd /root/backup
cp passwd /etc/ >/dev/null 2>&1
cp group /etc/ >/dev/null 2>&1
cp shadow /etc/ >/dev/null 2>&1
cp gshadow /etc/ >/dev/null 2>&1
cp crontab /etc/ >/dev/null 2>&1
cp -r xray /etc/ >/dev/null 2>&1
cp -r funny /etc/ >/dev/null 2>&1
cp -r creare /var/log/ >/dev/null 2>&1
clear
cd
rm -rf /root/backup
rm -f backup.zip
clear
systemctl daemon-reload >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart xray@ws >/dev/null 2>&1
systemctl restart xray@grpc >/dev/null 2>&1
systemctl restart xray@split >/dev/null 2>&1
systemctl restart xray@upgrade >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
systemctl restart cron >/dev/null 2>&1
clear
cd /root
mv /var/www/uploads/*.zip /root/backup.zip
file="backup.zip"
if [ -f "$file" ]; then
echo "$file ditemukan, melanjutkan proses..."
sleep 2
clear
unzip backup.zip
rm -f backup.zip
sleep 1
echo "Tengah Melakukan Backup Data"
cd /root/backup
cp passwd /etc/ >/dev/null 2>&1
cp group /etc/ >/dev/null 2>&1
cp shadow /etc/ >/dev/null 2>&1
cp gshadow /etc/ >/dev/null 2>&1
cp crontab /etc/ >/dev/null 2>&1
cp -r xray /etc/ >/dev/null 2>&1
cp -r funny /etc/ >/dev/null 2>&1
cp -r creare /var/log/ >/dev/null 2>&1
clear
cd
rm -rf /root/backup
rm -f backup.zip
clear
systemctl daemon-reload >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart xray@ws >/dev/null 2>&1
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