#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Found 523: missing or invalid markers are explicit states, not "Unknown".
version_label() {
    local file="$1" fallback="$2" value=""
    [ -r "$file" ] && value=$(tr -d '[:space:]' < "$file" 2>/dev/null)
    case "$value" in
        ""|Unknown|unknown) printf '%s' "$fallback" ;;
        *[!0-9a-f]*) printf '%s' "$fallback" ;;
        *) printf '%s' "${value:0:7}" ;;
    esac
}

# Found 527: show the licence identity without gating the menu. The two auth
# sources are raced briefly; if both are unreachable the last good match is
# shown as cached and the menu still opens.
license_cache_file="/var/lib/fn-autosc/license-info"

license_payload_ok() {
    awk 'NF >= 4 && $1 == "###" { ok = 1 } END { exit !ok }' "$1" 2>/dev/null
}

license_refresh() {
    local tmp data="" end p1 p2 running
    tmp=$(mktemp -d) || return 1
    curl -4 -fsSL --max-time 3 "https://fn-autosc-auth.pages.dev/izin.txt" -o "$tmp/pages" 2>/dev/null & p1=$!
    curl -4 -fsSL --max-time 3 "https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt" -o "$tmp/github" 2>/dev/null & p2=$!
    end=$((SECONDS+4))
    while [ $SECONDS -lt $end ]; do
        for f in "$tmp/pages" "$tmp/github"; do
            if license_payload_ok "$f"; then data=$(cat "$f"); break 2; fi
        done
        running=$(jobs -pr)
        if ! printf '%s\n' "$running" | grep -qx "$p1" && ! printf '%s\n' "$running" | grep -qx "$p2"; then break; fi
        sleep 1
    done
    kill "$p1" "$p2" 2>/dev/null
    wait "$p1" "$p2" 2>/dev/null
    rm -rf "$tmp"
    [ -n "$data" ] || return 1
    printf '%s\n' "$data"
}

license_expiry_label() {
    local expiry="$1" expired_epoch today
    if [ "$expiry" = "lifetime" ]; then
        printf 'lifetime'
        return 0
    fi
    today=$(date +%s)
    if expired_epoch=$(date -d "$expiry" +%s 2>/dev/null); then
        printf '%s (%d days)' "$expiry" $(( (expired_epoch - today) / 86400 ))
    else
        printf '%s' "$expiry"
    fi
}

license_match_for_ip() {
    local data="$1" ip="$2"
    [ -n "$ip" ] || return 1
    printf '%s\n' "$data" | grep "###" | grep -wF "$ip" | head -n 1
}

license_display() {
    local data="" match="" cached="" cache_tmp="" ip="" install_ip="" cache_ip="" expiry=""
    ip=$(printf '%s\n' "${ip_display:-}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    [ -n "$ip" ] || ip=$(tr -d '[:space:]' < /etc/.ip 2>/dev/null)
    install_ip=$(tr -d '[:space:]' < /etc/.ip 2>/dev/null)

    if data=$(license_refresh); then
        match=$(license_match_for_ip "$data" "$ip")
        if [ -z "$match" ] && [ -n "$install_ip" ] && [ "$install_ip" != "$ip" ]; then
            match=$(license_match_for_ip "$data" "$install_ip")
        fi
        if [ -n "$match" ]; then
            mkdir -p "$(dirname "$license_cache_file")" 2>/dev/null
            cache_tmp="${license_cache_file}.$$"
            if printf '%s\n' "$match" > "$cache_tmp" 2>/dev/null; then
                chmod 600 "$cache_tmp" 2>/dev/null
                mv -f "$cache_tmp" "$license_cache_file" 2>/dev/null || rm -f "$cache_tmp" 2>/dev/null
            fi
            expiry=$(printf '%s\n' "$match" | awk '{print $4}')
            echo "Username          : $(printf '%s\n' "$match" | awk '{print $2}')"
            echo "IPv4              : $(printf '%s\n' "$match" | awk '{print $3}')"
            echo "Expired           : $(license_expiry_label "$expiry")"
            return 0
        fi
        rm -f "$license_cache_file" 2>/dev/null
        echo "Username          : unlicensed"
        echo "IPv4              : ${ip:-${install_ip:-unknown}}"
        echo "Expired           : none"
        return 0
    fi

    cached=$(head -n 1 "$license_cache_file" 2>/dev/null)
    case "$cached" in
        "### "*)
            cache_ip=$(printf '%s\n' "$cached" | awk '{print $3}')
            expiry=$(printf '%s\n' "$cached" | awk '{print $4}')
            if [ -n "$cache_ip" ] && [ -n "$expiry" ] && { [ "$cache_ip" = "$ip" ] || { [ -n "$install_ip" ] && [ "$cache_ip" = "$install_ip" ]; }; }; then
                echo "Username          : $(printf '%s\n' "$cached" | awk '{print $2}') (cached)"
                echo "IPv4              : $cache_ip (cached)"
                echo "Expired           : $(license_expiry_label "$expiry") (cached)"
                return 0
            fi
            ;;
    esac
    echo "Username          : unavailable"
    echo "IPv4              : ${ip:-${install_ip:-unavailable}}"
    echo "Expired           : not checked"
}

output() {
    license_display
    _installed=$(version_label /etc/funny/.install-commit "not recorded")
    _updated=$(version_label /etc/funny/.update-commit "not updated")
    echo "Installed version : $_installed"
    echo "Updated version   : $_updated"
}


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
    echo "$(printf "%.2f" $(echo "scale=2; $value / 1024" | bc)) GB"
  else
    echo "$(printf "%.2f" $value) MB"
  fi
}

ttoday=$(format_usage "$total_today")
tyest=$(format_usage "$total_yesterday")
tmon=$(format_usage "$total_month")
clear
echo ""
echo ""
### Warna / Collor jir
export red='\033[0;31m'
export green='\033[0;32m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'
export blue='\033[1;34m'
export purple='\033[1;35m'
export orange='\033[38;5;208m'
export BICyan='\033[0;36m'

rainbow_sep() {
  local text="${1:-----------------------------}"
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



clear
echo ""
echo ""
menu-x() {

rerechan=$(output)

# Status Service
status="$(systemctl show nginx.service --no-page)"
status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status_text}" == "active" ]
then
echo -e "${NC}: "${green}"running"$NC" ✓"
else
echo -e "${NC}: "$red"not running (Error)"$NC" "
fi

# Total Akun
ws=$(cat /etc/xray/json/ws.json | grep "###" | sort | uniq | wc -l)
http=$(cat /etc/xray/json/upgrade.json | grep "###" | sort | uniq | wc -l)
gpc=$(cat /etc/xray/json/grpc.json | grep "###" | sort | uniq | wc -l)
xhttp=$(cat /etc/xray/json/xhttp.json | grep "###" | sort | uniq | wc -l)

# Xray/XTLS core version
xver=$(xray version 2>/dev/null | awk '{print $2}' | head -n 1)

separator=$(rainbow_sep '-----------------------------------')
blue_sep="${blue}-----------------------------------${NC}"
clear
echo ""
echo ""
echo -e "${NC}${separator}
             XTLS MENU
${separator}
Nginx        : $(status="$(systemctl show nginx.service --no-page)"
status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status_text}" == "active" ]
then
echo -e "${green}running${NC} ✓"
else
echo -e "${red}not running (Error)${NC}"
fi)
XTLS Version : ${xver:-unknown}
${blue_sep}
${purple}TOTAL ACCOUNTS${NC}
WS           : ${green}$ws${NC}
HU           : ${green}$http${NC}
gRPC         : ${green}$gpc${NC}
XHTTP        : ${green}$xhttp${NC}
${blue_sep}
${purple}MENU${NC}
${green}1${NC}. WebSocket        ${green}5${NC}. System Menu
${green}2${NC}. HTTP Upgrade   ${green}6${NC}. Domain Menu
${green}3${NC}. gRPC           ${green}7${NC}. Backup Menu
${green}4${NC}. XHTTP    ${green}8${NC}. Telegram Bot
${blue_sep}
Today: ${red}$ttoday${NC} Yesterday: ${red}$tyest${NC} This month: ${red}$tmon${NC}
${separator}
$rerechan
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opws || exit 0
case $opws in
1) clear ; x-ws ; menu-x ;;
2) clear ; x-http ; menu-x ;;
3) clear ; x-grpc ; menu-x ;;
4) clear ; x-xhttp ; menu-x ;;
5) clear ; menu-system ; menu-x ;;
6) clear ; dm-menu ; menu-x ;;
7) clear ; bmenu ; menu-x ;;
8) clear ; menu-bot ; menu-x ;;
*) clear ; menu-x ;;
esac
}

menu-x
