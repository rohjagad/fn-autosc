#!/bin/bash
# Found 525: license is enforced only for create/extend/install.


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


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

# Versions of the SSH front-ends a client actually connects through - the ones
# the account card shows as connection methods: OpenSSH, Dropbear, the SSH
# WebSocket and the 777 TLS front-end. Each falls back to n/a when its binary is
# absent, so the menu still renders on a partial install (see is-decision.md 27).
v_openssh=$(ssh -V 2>&1 | awk '{print $1}' | sed 's/^OpenSSH_//')
v_dropbear=$(dropbear -V 2>&1 | awk '{print $2}')
v_ws=$(timeout 5 ws version 2>/dev/null | head -n 1 | grep -oE 'v[0-9.]+' | head -n 1)
v_stunnel=$(stunnel -version 2>&1 | grep -oE 'stunnel [0-9.]+' | head -n 1 | awk '{print $2}')
# The 777 front-end is HAProxy in this panel (installer/stunnel5.sh), so fall
# back to its version instead of showing n/a for an active service.
[ -n "$v_stunnel" ] || v_stunnel=$(haproxy -v 2>&1 | grep -oE 'HAProxy version [0-9.]+' | head -n 1 | awk '{print $3}')

clear
echo ""
echo ""
echo -e "${NC}${separator}
             SSH MENU
${separator}
${purple}SSH SERVICES${NC}
OpenSSH   : ${v_openssh:-n/a}
Dropbear  : ${v_dropbear:-n/a}
WS ePro   : ${v_ws:-n/a}
Stunnel5  : ${v_stunnel:-n/a}
${blue_sep}
${green}1${NC}. Create SSH Account
${green}2${NC}. Trial SSH Account
${green}3${NC}. Delete SSH Account
${green}4${NC}. Check Online SSH Users
${green}5${NC}. Check SSH Account Logs
${green}6${NC}. Extend SSH Account
${green}7${NC}. List SSH Accounts
${green}8${NC}. Change SSH Password
${green}9${NC}. Change SSH IP Limit
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " aws || exit 0
    case $aws in
    1) clear ; addssh ; menu-ssh ;;
    2) clear ; trial-ssh ; menu-ssh ;;
    3) clear ; delete-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    4) clear ; cek-login-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    5) clear ; log-acc-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    6) clear ; extend-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    7) clear ; list-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    8) clear ; pwd-ssh ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    9) clear ; limit-ip ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menu-ssh ;;
    0|00) clear ; menu ;;
    *) clear ; menu-ssh ;;
    esac
