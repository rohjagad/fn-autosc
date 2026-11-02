#!/bin/bash
# Found 525: license is enforced only for create/extend/install.


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


# Color
red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
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

menu-x() {

# Status Service
status="$(systemctl show nginx.service --no-page)"
status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status_text}" == "active" ]; then
    stat_msg="${green}ON${NC}"
else
    stat_msg="${red}OFF${NC}"
fi

# Total Akun
ws=$(cat /etc/xray/json/ws.json 2>/dev/null | grep "###" | sort | uniq | wc -l)
http=$(cat /etc/xray/json/upgrade.json 2>/dev/null | grep "###" | sort | uniq | wc -l)
gpc=$(cat /etc/xray/json/grpc.json 2>/dev/null | grep "###" | sort | uniq | wc -l)
xhttp=$(cat /etc/xray/json/xhttp.json 2>/dev/null | grep "###" | sort | uniq | wc -l)

# Xray/XTLS core version (moved here from the main menu, which is too cramped)
xver=$(xray version 2>/dev/null | awk '{print $2}' | head -n 1)

clear
echo ""
echo ""
echo -e "${NC}${separator}
            XTLS MENU
${separator}
Status       : $stat_msg
XTLS Version : ${xver:-unknown}
${blue_sep}
${purple}TOTAL ACCOUNTS${NC}
WS           : $ws
HU           : $http
XHTTP        : $xhttp
gRPC         : $gpc
${blue_sep}
${purple}MENU${NC}
${green}1${NC}. WebSocket
${green}2${NC}. HTTP Upgrade
${green}3${NC}. XHTTP
${green}4${NC}. gRPC
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opws || exit 0
case $opws in
1) clear ; x-ws ; menu-x ;;
2) clear ; x-http ; menu-x ;;
3) clear ; x-xhttp ; menu-x ;;
4) clear ; x-grpc ; menu-x ;;
0|00) clear ; menu ;;
*) clear ; menu-x ;;
esac
}

menu-x
