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
xver=$(xray version | awk '{print $2}' | head -n 1)
domain=$(cat /etc/xray/domain)
ip6=$(curl -sS ipv4.icanhazip.com)
ip4=$(curl -sS ipv6.icanhazip.com)
sshd="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
ws=$(cat /etc/v2ray/config.json | grep "###" | sort | uniq | wc -l)
http=$(cat /etc/xray/json/upgrade.json | grep "###" | sort | uniq | wc -l)
gpc=$(cat /etc/xray/json/grpc.json | grep "###" | sort | uniq | wc -l)
split=$(cat /etc/xray/json/split.json | grep "###" | sort | uniq | wc -l)
uptime=$(uptime | awk '{print $1, $2, $3, $4, $5}')
isp=$(cat /root/.isp)
region=$(cat /root/.region)
clear

#Download/Upload today
#dtoday="$(vnstat -i eth0 | grep "today" | awk '{print $2" "substr ($3, 1, 1)}')"
#utoday="$(vnstat -i eth0 | grep "today" | awk '{print $5" "substr ($6, 1, 1)}')"
#ttoday="$(vnstat -i eth0 | grep "today" | awk '{print $8" "substr ($9, 1, 1)}')"
#Download/Upload yesterday
#dyest="$(vnstat -i eth0 | grep "yesterday" | awk '{print $2" "substr ($3, 1, 1)}')"
#uyest="$(vnstat -i eth0 | grep "yesterday" | awk '{print $5" "substr ($6, 1, 1)}')"
#tyest="$(vnstat -i eth0 | grep "yesterday" | awk '{print $8" "substr ($9, 1, 1)}')"
#Download/Upload current month
#dmon="$(vnstat -i eth0 -m | grep "`date +"%b '%y"`" | awk '{print $3" "substr ($4, 1, 1)}')"
#umon="$(vnstat -i eth0 -m | grep "`date +"%b '%y"`" | awk '{print $6" "substr ($7, 1, 1)}')"
#tmon="$(vnstat -i eth0 -m | grep "`date +"%b '%y"`" | awk '{print $9" "substr ($10, 1, 1)}')"
clear

# Fungsi untuk membaca data vnstat
read_vnstat_usage() {
  local interface=$1
  local today=$(vnstat -i "$interface" | grep "today" | awk '{print $8" "$9}')
  local yesterday=$(vnstat -i "$interface" | grep "yesterday" | awk '{print $8" "$9}')
  local this_month=$(vnstat -i "$interface" -m | grep "$(date +"%b '%y")" | awk '{print $9" "$10}')
  
  echo "$today;$yesterday;$this_month"
}

# Fungsi untuk mengonversi ke satuan MB
convert_to_mb() {
  local value=$1
  local unit=$2
  
  case $unit in
    B) echo "scale=6; $value / 1048576" | bc ;;
    KiB) echo "scale=6; $value / 1024" | bc ;;
    MiB) echo "$value" ;;
    GiB) echo "scale=6; $value * 1024" | bc ;;
    TiB) echo "scale=6; $value * 1048576" | bc ;;
    *) echo "0" ;;
  esac
}

# Mendapatkan semua interface
all_interfaces=$(vnstat --iflist | sed 's/Available interfaces: //')
if [ -z "$all_interfaces" ]; then
  echo "Tidak ada interface yang tersedia di vnstat."
  exit 1
fi

total_today=0
total_yesterday=0
total_month=0

for iface in $all_interfaces; do
  echo "Memproses interface: $iface"
  result=$(read_vnstat_usage "$iface")
  echo "Hasil untuk $iface: $result"
  
  today=$(echo "$result" | awk -F';' '{print $1}')
  yesterday=$(echo "$result" | awk -F';' '{print $2}')
  month=$(echo "$result" | awk -F';' '{print $3}')
  
  today_value=$(echo "$today" | awk '{print $1}')
  today_unit=$(echo "$today" | awk '{print $2}')
  
  yesterday_value=$(echo "$yesterday" | awk '{print $1}')
  yesterday_unit=$(echo "$yesterday" | awk '{print $2}')
  
  month_value=$(echo "$month" | awk '{print $1}')
  month_unit=$(echo "$month" | awk '{print $2}')
  
  total_today=$(echo "$total_today + $(convert_to_mb $today_value $today_unit)" | bc)
  total_yesterday=$(echo "$total_yesterday + $(convert_to_mb $yesterday_value $yesterday_unit)" | bc)
  total_month=$(echo "$total_month + $(convert_to_mb $month_value $month_unit)" | bc)
done

# Format hasil
format_usage() {
  local value=$1
  if (( $(echo "$value >= 1024" | bc -l) )); then
    echo "$(printf "%.2f" $(echo "$value / 1024" | bc)) GB"
  else
    echo "$(printf "%.2f" $value) MB"
  fi
}

ttoday=$(format_usage "$total_today")
tyest=$(format_usage "$total_yesterday")
tmon=$(format_usage "$total_month")

### Warna / Collor jir
export red='\033[0;31m'
export green='\033[0;32m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'
export BICyan='\033[0;36m'

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

### Status SSH
cek=$(service ssh status | grep active | cut -d ' ' -f5)
if [ "$cek" = "active" ]; then
stat=-f5
else
stat=-f7
fi
ssh=$(service ssh status | grep active | cut -d ' ' $stat)
if [ "$ssh" = "active" ]; then
resh="${green}ON${NC}"
else
resh="${red}OFF${NC}"
fi

### Status XTLS WebSocket
vxws=$(service v2ray status | grep active | cut -d ' ' $stat)
if [ "$vxws" = "active" ]; then
xws="${green}ON${NC}"
else
xws="${red}OFF${NC}"
fi

### Status XTLS HTTP UPGRADE
vxhttp=$(service xray@upgrade status | grep active | cut -d ' ' $stat)
if [ "$vxhttp" = "active" ]; then
xhttp="${green}ON${NC}"
else
xhttp="${red}OFF${NC}"
fi

### Status XTLS SPLIT HTTP
vxsplit=$(service xray@split status | grep active | cut -d ' ' $stat)
if [ "$vxsplit" = "active" ]; then
xsplit="${green}ON${NC}"
else
xsplit="${red}OFF${NC}"
fi

### Status XTLS gRPC
vxgpc=$(service xray@grpc status | grep active | cut -d ' ' $stat)
if [ "$vxgpc" = "active" ]; then
xgcp="${green}ON${NC}"
else
xgcp="${red}OFF${NC}"
fi

### Status WebSocket ePro
aws=$(service ws status | grep active | cut -d ' ' $stat)
if [ "$aws" = "active" ]; then
pro="${green}ON${NC}"
else
pro="${red}OFF${NC}"
fi

### Status Loadbalance
ngx=$(service nginx status | grep active | cut -d ' ' $stat)
if [ "$ngx" = "active" ]; then
loadbalance="${green}ON${NC}"
else
loadbalance="${red}OFF${NC}"
fi
rechan=$(output)
separator=$(rainbow_sep '===================================')
clear
echo -e "
${NC}
 ${separator}
<=   MENU MANAGEMENT PANEL VPN   =>
 ${separator}
VERSION XTLS : $xver
DOMAIN SERVER: $domain
IP SERVER    : $ip4 / $ip6
Uptime       : $uptime
ISP / REGION : $isp / $region
 ${separator}
         Total Account

SSH SERVER   : $sshd
XTLS WS      : $ws
XTLS HTTP UP : $http
XTLS SPLIT   : $split
XTLS gRPC    : $gpc
 ${separator}
SSH: $resh | WS: $xws | HTTP: $xhttp
SPLIT: $xsplit | gRPC: $xgcp | ePRO: $pro
Loadbalance: $loadbalance
 ${separator}

1. Menu SSH     4. Menu SlowDNS
2. Menu XTLS    5. Menu Backup
3. Menu Domain  6. Menu Bot Telegram

7. Menu L2TP    8. Menu Wireguard
       9.  Menu NoobzVPN
       10. Menu System
 ${separator}
Today${NC}: ${red}$ttoday${NC} Yesterday${NC}: ${red}$tyest${NC} This month${NC}: ${red}$tmon${NC}
 ${separator}
${rechan}
 ${separator}
 [   PRESS CTRL  +  C TO EXIT    ]
 ${separator}
"
read -p "Input Option: " opw
case $opw in
1) clear ; menu-ssh ;;
2) clear ; menu-x ;;
3) clear ; dm-menu ;;
4) clear ; menu-dnstt ;;
5) clear ; bmenu ;;
6) clear ; menu-bot ;;
7) clear ; xl2tp ;;
8) clear ; menu-wg ;;
9) clear ; menu-noobz ;;
10) clear ; menu-system ;;
*) menu ;;
esac
