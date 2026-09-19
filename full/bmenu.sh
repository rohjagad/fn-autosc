#!/bin/bash


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/1.23/izin.txt"
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
ip6=$(curl -sS ipv4.icanhazip.com)
ip4=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
read -rp "Input Link Database: " url

cd /root
wget -O backup.zip "$url"
unzip backup.zip
rm -f backup.zip
sleep 1
echo "Tengah Melakukan Backup Data"
cd /root/backup
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp crontab /etc/
cp -r xray /etc/
cp -r v2ray /etc/
cp -r funny /etc/
cp -r create /var/log/

systemctl daemon-reload
systemctl restart ssh
systemctl restart v2ray
systemctl restart xray@ws
systemctl restart xray@grpc
systemctl restart xray@split
systemctl restart xray@upgrade
systemctl restart nginx
systemctl restart cron
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
rm -fr /root/backup*
}

restf() {
# Detail Informasi
ip6=$(curl -sS ipv4.icanhazip.com)
ip4=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
cd /root
mv /root/*.zip /root/backup.zip
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
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp crontab /etc/
cp -r xray /etc/
cp -r v2ray /etc/
cp -r funny /etc/
cp -r create /var/log/

systemctl daemon-reload
systemctl restart ssh
systemctl restart v2ray
systemctl restart xray@ws
systemctl restart xray@grpc
systemctl restart xray@split
systemctl restart xray@upgrade
systemctl restart nginx
systemctl restart cron
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
else
    echo "Error: File $file Not Found"
fi
rm -fr /root/backup*
}

resold() {
# Detail Informasi
ip6=$(curl -sS ipv4.icanhazip.com)
ip4=$(curl -sS ipv6.icanhazip.com)
ip="$ip4 / $ip6"
date=$(date)
domain=$(cat /etc/xray/domain)
clear
read -rp "Input Link Database: " url

cd /root
wget -O backup.zip "$url"
unzip backup.zip
rm -f backup.zip
sleep 1
echo "Tengah Melakukan Backup Data"
cd /root/backup
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp crontab /etc/
cp -r xray /etc/
cp -r funny /etc/
cp -r create /var/log/

# Mengubah Database XTLS WebSocket Ke V2ray WebSocket
cd /etc/xray/json
mv ws.json /etc/v2ray/config.json
sed -i "s/rerechan-store/$(xray uuid)/g" /etc/v2ray/config.json
sed -i 's|/var/log/xray/ws.log|/var/log/v2ray/access.log|g' /etc/v2ray/config.json

# Mengambil Lokasi Xray Config
XRAY_CONFIG="/etc/v2ray/config.json"

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/v2ray/config.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/v2ray/config.json
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
        \"statsUserUplink\": true
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
systemctl restart v2ray
systemctl restart xray@ws
systemctl restart xray@grpc
systemctl restart xray@split
systemctl restart xray@upgrade
systemctl restart nginx
systemctl restart cron
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
rm -fr /root/backup*
}

bmenu() {
clear
echo -e "${NC}${separator}
            MENU BACKUP
${separator}
${green}1${NC}. Backup Database 1
${green}2${NC}. Backup Database 2
${green}3${NC}. Restore Database Via Link
${green}4${NC}. Restore Database Via File
${green}5${NC}. Restore Old Database Script Version Under v23
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opa
case $opa in
1) clear ; backup ;;
2) clear ; backup-gd ;;
3) clear ; restore ;;
4) clear ; restf ;;
5) clear ; resold ;;
*) clear ; bmenu ;;
esac
}

bmenu
