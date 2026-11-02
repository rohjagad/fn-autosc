#!/bin/bash
# Found 525: license is enforced only for create/extend/install.


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


# Color
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

# Fungsi untuk menghitung jumlah akun di file ws.json
countAccounts() {
    filePath="$1"
    count=$(grep "###" "$filePath" 2>/dev/null | sort | uniq | wc -l)
    echo $count
}

# Fungsi untuk membersihkan layar
clearScreen() {
    clear
    echo ""
    echo ""
}

# Fungsi utama untuk menampilkan menu dan menangani pilihan pengguna
xws() {
    ws=$(countAccounts "/etc/xray/json/ws.json")

    clearScreen
    echo -e "${NC}${separator}
          XTLS WEBSOCKET
${separator}
WS           : ${green}$ws${NC}
${blue_sep}
${purple}CREATE ACCOUNT${NC}
${green}01${NC}. Create VMess Account
${green}02${NC}. Create VLess Account
${green}03${NC}. Create Trojan Account
${blue_sep}
${purple}TRIAL ACCOUNT${NC}
${green}04${NC}. Trial VMess Account
${green}05${NC}. Trial VLess Account
${green}06${NC}. Trial Trojan Account
${blue_sep}
${purple}MANAGE ACCOUNT${NC}
${green}07${NC}. Check Online Users
${green}08${NC}. Delete Account
${green}09${NC}. Extend Account
${green}10${NC}. Check Database Logs
${green}11${NC}. List All Accounts
${green}12${NC}. Change UUID / Password
${green}13${NC}. Unlock WS Account
${green}14${NC}. Xray Routing Config
${green}15${NC}. Change WS IP Limit
${green}16${NC}. Change WS Quota Limit
${green}17${NC}. Lock WS Account
${green}00${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
    read -p "Input option: " opws || exit 0

    # Menangani pilihan berdasarkan input pengguna
    case $opws in
        1|01) clearScreen; add-vmess-ws ; xws ;;
        2|02) clearScreen; add-vless-ws ; xws ;;
        3|03) clearScreen; add-trojan-ws ; xws ;;
        4|04) clearScreen; trial-vmess-ws ; xws ;;
        5|05) clearScreen; trial-vless-ws ; xws ;;
        6|06) clearScreen; trial-trojan-ws ; xws ;;
        7|07) clearScreen; cek-xray-ws  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        8|08) clearScreen; delete-ws ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        9|09) clearScreen; extend-ws ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        10) clearScreen; log-database-xray-ws  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        11) clearScreen; list-xray-ws  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        12) clearScreen; change-id-ws ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        13) clearScreen; unlock-ws ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        14) clearScreen; routing-ws ; xws ;;
        15) clearScreen; change-limit-ip-ws ; xws ;;
        16) clearScreen; change-quota-ws ; xws ;;
        17) clearScreen; locked-xray-ws ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xws ;;
        0|00) clearScreen; menu ;;
        *) clearScreen; xws ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xws
