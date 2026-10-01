#!/bin/bash
# Detail Informasi
ip4=$(curl -sS ipv4.icanhazip.com)
ip6=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
cd /root
# Check both upload and root locations
newest=$(ls -t /var/www/uploads/*.zip 2>/dev/null | head -1)
if [ -n "$newest" ]; then
    mv "$newest" /root/backup.zip
else
    newest=$(ls -t /root/*backup*.zip 2>/dev/null | head -1)
    [ -n "$newest" ] && [ "$newest" != "/root/backup.zip" ] && mv "$newest" /root/backup.zip
fi
file="backup.zip"
if [ -f "$file" ]; then
echo "$file found, continuing..."
sleep 2
clear
unzip -o backup.zip
rm -f backup.zip
sleep 1
echo "Restoring backup data..."
cd /root/backup
cp passwd /etc/ >/dev/null 2>&1
cp group /etc/ >/dev/null 2>&1
cp shadow /etc/ >/dev/null 2>&1
cp gshadow /etc/ >/dev/null 2>&1
cp crontab /etc/ >/dev/null 2>&1
cp -r xray /etc/ >/dev/null 2>&1
cp -r funny /etc/ >/dev/null 2>&1
cp -r create /var/log/ >/dev/null 2>&1
cp -r wireguard /etc/ >/dev/null 2>&1 || true
cp -r slowdns /etc/ >/dev/null 2>&1 || true
cp -r noobzvpns /etc/ >/dev/null 2>&1 || true
cp -r haproxy /etc/ >/dev/null 2>&1 || true
cp -r ppp /etc/ >/dev/null 2>&1 || true
cp -r ipsec.d /etc/ >/dev/null 2>&1 || true
cp ipsec.secrets /etc/ >/dev/null 2>&1 || true
mkdir -p /var/www/html
cp -r html/* /var/www/html/ >/dev/null 2>&1 || true
clear
cd
rm -rf /root/backup
rm -f backup.zip
clear
systemctl daemon-reload
systemctl restart ssh
systemctl restart dropbear 2>/dev/null || true
systemctl restart ws 2>/dev/null || true
systemctl restart xray@ws
systemctl restart xray@grpc
systemctl restart xray@split
systemctl restart xray@upgrade
systemctl restart quota-ws 2>/dev/null || true
systemctl restart quota-http 2>/dev/null || true
systemctl restart quota-split 2>/dev/null || true
systemctl restart quota-grpc 2>/dev/null || true
systemctl restart nginx
mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 600 /etc/haproxy/funny.pem 2>/dev/null
systemctl restart haproxy 2>/dev/null || true
systemctl restart cron
systemctl restart wg-quick@wg0 2>/dev/null || true
systemctl restart dnstt 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
systemctl restart xl2tpd 2>/dev/null || true
systemctl restart ipsec 2>/dev/null || true
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
