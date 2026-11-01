#!/bin/bash

# Found 511: /etc/funny contains version markers and the formatter. A data
# backup must not roll the running panel back; keep the current copies
# across the restore, and drop restored markers when no current copy exists.
restore_funny_data() {
    local keep f
    keep=$(mktemp -d 2>/dev/null) || keep="/tmp/fn-funny-keep.$$"
    mkdir -p "$keep" 2>/dev/null || { cp -r funny /etc/; return; }
    for f in .install-commit .update-commit version format.sh; do
        [ -f "/etc/funny/$f" ] && cp -a "/etc/funny/$f" "$keep/"
    done
    cp -r funny /etc/
    for f in .install-commit .update-commit version; do
        if [ -f "$keep/$f" ]; then
            cp -a "$keep/$f" "/etc/funny/$f"
        else
            rm -f "/etc/funny/$f"
        fi
    done
    [ -f "$keep/format.sh" ] && cp -a "$keep/format.sh" "/etc/funny/format.sh"
    rm -rf "$keep"
}

# Found 521: backups made before the domain rename carry /etc/xray/domain,
# /etc/xray/domains, and /etc/xray/.domainseq.  Normalize the unpacked copy
# before it lands in /etc/xray; when both names exist, the new one wins.
normalize_backup_domains() {
    local b="/root/backup/xray"
    [ -d "$b" ] || return 0
    if [ -f "$b/domain" ]; then
        [ -f "$b/installer-domain" ] || cp -a "$b/domain" "$b/installer-domain"
        rm -f "$b/domain"
    fi
    if [ -f "$b/domains" ]; then
        [ -f "$b/rotated-domains" ] || cp -a "$b/domains" "$b/rotated-domains"
        rm -f "$b/domains"
    fi
    if [ -f "$b/.domainseq" ]; then
        [ -f "$b/.rotated-domainseq" ] || cp -a "$b/.domainseq" "$b/.rotated-domainseq"
        rm -f "$b/.domainseq"
    fi
}

cleanup_legacy_domain_files() {
    [ -f /etc/xray/installer-domain ] && rm -f /etc/xray/domain
    [ -f /etc/xray/rotated-domains ] && rm -f /etc/xray/domains
    [ -f /etc/xray/.rotated-domainseq ] && rm -f /etc/xray/.domainseq
    return 0
}

# Detail Informasi
ip4=$(curl -sS -m 10 ipv4.icanhazip.com)
ip6=$(curl -sS -m 10 ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
installer_domain=$(cat /etc/xray/installer-domain)
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
if ! unzip -tq backup.zip >/dev/null 2>&1; then
    echo "Error: file is not a valid zip archive."
    rm -f backup.zip
    sleep 2
    return
fi
unzip -o backup.zip
rm -f backup.zip
sleep 1
echo "Restoring backup data..."
cd /root/backup || { echo "Error: backup dir missing."; sleep 2; return; }
normalize_backup_domains
cp passwd /etc/ >/dev/null 2>&1
cp group /etc/ >/dev/null 2>&1
cp shadow /etc/ >/dev/null 2>&1
cp gshadow /etc/ >/dev/null 2>&1
cp crontab /etc/ >/dev/null 2>&1
cp -r xray /etc/ >/dev/null 2>&1
cleanup_legacy_domain_files >/dev/null 2>&1
restore_funny_data >/dev/null 2>&1
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
if xray run -test -config /etc/xray/json/ws.json >/dev/null 2>&1; then systemctl restart xray@ws; fi
if xray run -test -config /etc/xray/json/grpc.json >/dev/null 2>&1; then systemctl restart xray@grpc; fi
if xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then systemctl restart xray@xhttp; fi
if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then systemctl restart xray@upgrade; fi
systemctl restart quota-ws 2>/dev/null || true
systemctl restart quota-http 2>/dev/null || true
systemctl restart quota-xhttp 2>/dev/null || true
systemctl restart quota-grpc 2>/dev/null || true
systemctl restart nginx
mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null || true
chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/params /etc/ipsec.secrets* /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.keybot /etc/funny/.chatid /etc/funny/.l2tp /etc/slowdns/server.key 2>/dev/null || true
chmod 640 /etc/funny/.restore.key 2>/dev/null || true
chmod 600 /etc/xray/.key 2>/dev/null || true
chown root:www-data /etc/funny/.restore.key 2>/dev/null || true
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
echo -e "INSTALLER DOMAIN : $installer_domain"
echo -e "DATE        : $date"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Error: File $file Not Found"
fi
