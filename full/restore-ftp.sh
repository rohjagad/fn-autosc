#!/bin/bash
# Found 525: license is enforced only for create/extend/install.
blue='\033[1;34m'
NC='\033[0m'

rainbow_sep() {
  local text="${1:------------------------------------}"
  local output=''
  local i segment fraction r g b color
  local -a red=(255 255 0 0 0 255 255)
  local -a green=(0 255 255 255 0 0 0)
  local -a blue=(0 0 0 255 255 255 0)
  for ((i = 0; i < ${#text}; i++)); do
    if ((i == ${#text} - 1)); then
      segment=5
      fraction=$((${#text} - 1))
    else
      segment=$((i * 6 / (${#text} - 1)))
      fraction=$((i * 6 % (${#text} - 1)))
    fi
    r=$((red[segment] + (red[segment + 1] - red[segment]) * fraction / (${#text} - 1)))
    g=$((green[segment] + (green[segment + 1] - green[segment]) * fraction / (${#text} - 1)))
    b=$((blue[segment] + (blue[segment + 1] - blue[segment]) * fraction / (${#text} - 1)))
    printf -v color '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
    output+="${color}${text:i:1}"
  done
  printf '%b\n' "${output}${NC}"
}

separator=$(rainbow_sep '-----------------------------------')
blue_sep="${blue}-----------------------------------${NC}"

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




[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
echo ""
echo ""
# Found 521: backups made before the domain rename carry /etc/xray/domain,
# /etc/xray/domains, and /etc/xray/.domainseq.  Normalize the unpacked copy
# before it lands in /etc/xray; when both names exist, the new one wins.
normalize_backup_domains() {
    local b="/root/backup/xray" legacy=0 d
    [ -d "$b" ] || return 0
    if [ -f "$b/domain" ]; then
        legacy=1
        [ -f "$b/installer-domain" ] || cp -a "$b/domain" "$b/installer-domain"
        rm -f "$b/domain"
    fi
    if [ -f "$b/domains" ]; then
        legacy=1
        [ -f "$b/rotated-domains" ] || cp -a "$b/domains" "$b/rotated-domains"
        rm -f "$b/domains"
    fi
    if [ -f "$b/.domainseq" ]; then
        [ -f "$b/.rotated-domainseq" ] || cp -a "$b/.domainseq" "$b/.rotated-domainseq"
        rm -f "$b/.domainseq"
    fi
    # Old backups relied on the installer domain being implicit in the
    # rotation. Seed it once so restored accounts keep a usable list; new
    # backups are left as-is, so a deleted installer entry stays deleted.
    if [ "$legacy" -eq 1 ] && [ -s "$b/installer-domain" ]; then
        d=$(tr -d '[:space:]' < "$b/installer-domain")
        if [ -n "$d" ] && ! grep -qxF "$d" "$b/rotated-domains" 2>/dev/null; then
            {
                printf '%s\n' "$d"
                if [ -s "$b/rotated-domains" ]; then
                    awk 'NF' "$b/rotated-domains"
                fi
            } > "$b/rotated-domains.tmp" || return 0
            mv -f "$b/rotated-domains.tmp" "$b/rotated-domains"
        fi
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
echo ""
echo ""
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
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp crontab /etc/
cp -r xray /etc/
cleanup_legacy_domain_files
restore_funny_data
cp -r create /var/log/
cp -r wireguard /etc/ 2>/dev/null || true
cp -r slowdns /etc/ 2>/dev/null || true
cp -r noobzvpns /etc/ 2>/dev/null || true
cp -r haproxy /etc/ 2>/dev/null || true
cp -r ppp /etc/ 2>/dev/null || true
cp -r ipsec.d /etc/ 2>/dev/null || true
cp ipsec.secrets /etc/ 2>/dev/null || true
mkdir -p /var/www/html
cp -r html/* /var/www/html/ 2>/dev/null || true
clear
echo ""
echo ""
cd
rm -rf /root/backup
rm -f backup.zip
clear
echo ""
echo ""
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
echo ""
echo ""
echo -e "${separator}"
echo -e "SUCCESSFULL RESTORE YOUR VPS"
echo -e "Please Save The Following Data"
echo -e "${separator}"
echo -e "Your VPS IP : $ip"
echo -e "DATE        : $date"
echo -e "${separator}"
else
    echo "Error: File $file Not Found"
fi
