#!/bin/bash


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_PRIMARY="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_FALLBACK="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s ifconfig.me) # Mendapatkan IP lokal

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
    PERMISSION_DATA=$(curl -s "$PERMISSION_PRIMARY" || curl -s "$PERMISSION_FALLBACK" || { echo "Failed to download permissions."; exit 1; })

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP is not in the database"
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
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"; fi
    }

clear

red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
NC='\033[0m'

rainbow_sep() {
  local text="${1:-===================================}"
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

separator=$(rainbow_sep '===================================')
blue_sep="${blue}-----------------------------------${NC}"

restore() {
# Detail Informasi
ip4=$(curl -sS ipv4.icanhazip.com)
ip6=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
read -rp "Input Link Database: " url || return
[ -z "$url" ] && return

cd /root
wget -O backup.zip "$url"
chmod 600 backup.zip 2>/dev/null || true
if [ ! -f backup.zip ] || ! unzip -tq backup.zip >/dev/null 2>&1; then
    echo "Error: Download failed or file is not a valid zip archive."
    rm -f backup.zip
    sleep 2
    return
fi
unzip -o backup.zip
rm -f backup.zip
sleep 1
echo "Restoring backup data..."
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
cp -r haproxy /etc/ 2>/dev/null || true
mkdir -p /var/www/html
cp -r html/* /var/www/html/ 2>/dev/null || true
mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null || true
chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/params /etc/ipsec.secrets* /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.keybot /etc/funny/.chatid /etc/funny/.l2tp 2>/dev/null || true
chmod 640 /etc/funny/.restore.key 2>/dev/null || true
chmod 600 /etc/xray/.key 2>/dev/null || true
chown root:www-data /etc/funny/.restore.key 2>/dev/null || true

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
systemctl restart haproxy 2>/dev/null || true
systemctl restart cron
systemctl restart wg-quick@wg0 2>/dev/null || true
systemctl restart dnstt 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
systemctl restart xl2tpd 2>/dev/null || true
systemctl restart ipsec 2>/dev/null || true
clear

#echo "Telah Berjaya Melakukan Backup"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "SUCCESSFULL RESTORE YOUR VPS"
    echo -e "Please Save The Following Data"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Your VPS IP : $ip"
    echo -e "DOMAIN      : $domain"
    echo -e "DATE        : $date"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
rm -fr /root/backup*
}

restf() {
# Detail Informasi
ip4=$(curl -sS ipv4.icanhazip.com)
ip6=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
cd /root
newest=$(ls -t /root/*.zip 2>/dev/null | head -1); [ -n "$newest" ] && [ "$newest" != "/root/backup.zip" ] && mv "$newest" /root/backup.zip
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
cp -r haproxy /etc/ 2>/dev/null || true
mkdir -p /var/www/html
cp -r html/* /var/www/html/ 2>/dev/null || true
mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null || true
chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/params /etc/ipsec.secrets* /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.keybot /etc/funny/.chatid /etc/funny/.l2tp 2>/dev/null || true
chmod 640 /etc/funny/.restore.key 2>/dev/null || true
chmod 600 /etc/xray/.key 2>/dev/null || true
chown root:www-data /etc/funny/.restore.key 2>/dev/null || true

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
systemctl restart haproxy 2>/dev/null || true
systemctl restart cron
systemctl restart wg-quick@wg0 2>/dev/null || true
systemctl restart dnstt 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
systemctl restart xl2tpd 2>/dev/null || true
systemctl restart ipsec 2>/dev/null || true
clear

#echo "Telah Berjaya Melakukan Backup"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e " VPS RESTORED SUCCESSFULLY "
    echo -e "Please save the following data:"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Your VPS IP : $ip"
    echo -e "DOMAIN      : $domain"
    echo -e "DATE        : $date"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
else
    echo "Error: File $file not found"
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
fi
rm -fr /root/backup*
}

resold() {
# Detail Informasi
ip4=$(curl -sS ipv4.icanhazip.com)
ip6=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
read -rp "Backup URL: " url || return
[ -z "$url" ] && return

cd /root
wget -O backup.zip "$url"
chmod 600 backup.zip 2>/dev/null || true
if [ ! -f backup.zip ] || ! unzip -tq backup.zip >/dev/null 2>&1; then
    echo "Error: Download failed or file is not a valid zip archive."
    rm -f backup.zip
    sleep 2
    return
fi
unzip -o backup.zip
rm -f backup.zip
sleep 1
echo "Restoring backup data..."
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
cp -r haproxy /etc/ 2>/dev/null || true
mkdir -p /var/www/html
cp -r html/* /var/www/html/ 2>/dev/null || true
mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null || true
chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/params /etc/ipsec.secrets* /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.keybot /etc/funny/.chatid /etc/funny/.l2tp 2>/dev/null || true
chmod 640 /etc/funny/.restore.key 2>/dev/null || true
chmod 600 /etc/xray/.key 2>/dev/null || true
chown root:www-data /etc/funny/.restore.key 2>/dev/null || true

# Repair the WS config a legacy backup has restored: replace the UUID
# placeholder, then re-append the standard outbounds/routing/stats block below.
# The config is already at the path the service reads, so nothing is moved.
cd /etc/xray/json
# A restored archive can still carry the committed defaults; replace all of them
# (not just "rerechan-store") with per-install random values, as the installer does.
for def in "rerechan-store" \
           "cfbbaafc-8d52-450c-9fb0-145bc8221e6d" \
           "019e0bf3-dd56-11e9-aa37-5600024c1d6a" \
           "af7d5cf8-442d-4bb3-8a76-eb367178781d" \
           "diy2020" \
           "nonescript-fn-project"; do
    rep="$(xray uuid)"
    sed -i "s|${def}|${rep}|g" \
        /etc/xray/json/ws.json /etc/xray/json/upgrade.json \
        /etc/xray/json/xhttp.json /etc/xray/json/grpc.json 2>/dev/null
done

# Mengambil Lokasi Xray Config
XRAY_CONFIG="/etc/xray/json/ws.json"

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/ws.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/ws.json
TEXT="
    \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
         \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true,
        \"statsUserOnline\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\" : true,
      \"statsOutboundDownlink\" : true
    }
  }
}"
# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Memulai Service
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
systemctl restart haproxy 2>/dev/null || true
systemctl restart cron
systemctl restart wg-quick@wg0 2>/dev/null || true
systemctl restart dnstt 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
systemctl restart xl2tpd 2>/dev/null || true
systemctl restart ipsec 2>/dev/null || true
clear

#echo "Telah Berjaya Melakukan Backup"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e " VPS RESTORED SUCCESSFULLY "
    echo -e "Please save the following data:"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Your VPS IP : $ip"
    echo -e "DOMAIN      : $domain"
    echo -e "DATE        : $date"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
rm -fr /root/backup*
}

bmenu() {
clear
echo -e "${NC}${separator}
            BACKUP MENU
${separator}
${green}1${NC}. Backup to Telegram
${green}2${NC}. Restore Backup via URL
${green}3${NC}. Restore Backup via File
${green}4${NC}. Restore Legacy Backup (< v1.23)
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opa || exit 0
case $opa in
1) clear ; backup ; bmenu ;;
2) clear ; restore ; bmenu ;;
3) clear ; restf ; bmenu ;;
4) clear ; resold ; bmenu ;;
0|00) clear ; menu ;;
*) clear ; bmenu ;;
esac
}

bmenu
