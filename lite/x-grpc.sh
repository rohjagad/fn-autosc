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

# Fungsi untuk menghitung jumlah akun di file grpc.json
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
xgrpc() {
    grpc=$(countAccounts "/etc/xray/json/grpc.json")

    clearScreen
    echo -e "${NC}${separator}
            XTLS gRPC
${separator}
gRPC         : ${green}$grpc${NC}
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
${green}13${NC}. Unlock gRPC Account
${green}14${NC}. Xray Routing Config
${green}15${NC}. Change gRPC IP Limit
${green}16${NC}. Change gRPC Quota Limit
${green}17${NC}. Lock gRPC Account
${green}00${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"

    # Input pilihan dari pengguna
    read -p "Input option: " opgrpc || exit 0

    # Menangani pilihan berdasarkan input pengguna
    case $opgrpc in
        1|01) clearScreen; add-vmess-grpc ; xgrpc ;;
        2|02) clearScreen; add-vless-grpc ; xgrpc ;;
        3|03) clearScreen; add-trojan-grpc ; xgrpc ;;
        4|04) clearScreen; trial-vmess-grpc ; xgrpc ;;
        5|05) clearScreen; trial-vless-grpc ; xgrpc ;;
        6|06) clearScreen; trial-trojan-grpc ; xgrpc ;;
        7|07) clearScreen; cek-xray-grpc  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        8|08) clearScreen; delete-grpc ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        9|09) clearScreen; extend-grpc ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        10) clearScreen; log-database-xray-grpc  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        11) clearScreen; list-xray-grpc  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        12) clearScreen; change-id-grpc ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        13) clearScreen; unlock-grpc ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        14) clearScreen; routing-grpc ; xgrpc ;;
        15) clearScreen; change-limit-ip-grpc ; xgrpc ;;
        16) clearScreen; change-quota-grpc ; xgrpc ;;
	17) clearScreen; locked-xray-grpc ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xgrpc ;;
        0|00) clearScreen; menu ;;
        *) clearScreen; xgrpc ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xgrpc
