#!/bin/bash


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
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
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL" || { echo "Failed to download permissions."; exit 1; })

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

# Color
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

# Fungsi untuk menghitung jumlah akun di file split.json
countAccounts() {
    filePath="$1"
    count=$(grep "###" "$filePath" 2>/dev/null | sort | uniq | wc -l)
    echo $count
}

# Fungsi untuk membersihkan layar
clearScreen() {
    clear
}

# Fungsi utama untuk menampilkan menu dan menangani pilihan pengguna
xsplit() {
    split=$(countAccounts "/etc/xray/json/split.json")

    clearScreen
    echo -e "${NC}${separator}
         XTLS SPLIT HTTP
${separator}
Split        : ${green}$split${NC}
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
${green}13${NC}. Unlock Split HTTP Account
${green}14${NC}. Xray Routing Config
${green}15${NC}. Change Split IP Limit
${green}16${NC}. Change Split Quota Limit
${green}17${NC}. Lock Split HTTP Account
${green}00${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"

    # Input pilihan dari pengguna
    read -p "Input option: " opsplit || exit 0

    # Menangani pilihan berdasarkan input pengguna
    case $opsplit in
        1|01) clearScreen; add-vmess-split ;;
        2|02) clearScreen; add-vless-split ;;
        3|03) clearScreen; add-trojan-split ;;
        4|04) clearScreen; trial-vmess-split ;;
        5|05) clearScreen; trial-vless-split ;;
        6|06) clearScreen; trial-trojan-split ;;
        7|07) clearScreen; cek-xray-split  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ;;
        8|08) clearScreen; delete-split ;;
        9|09) clearScreen; extend-split ;;
        10) clearScreen; log-database-xray-split  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ;;
        11) clearScreen; list-xray-split  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ;;
        12) clearScreen; change-id-split ;;
        13) clearScreen; unlock-split ;;
        14) clearScreen; routing-split ;;
        15) clearScreen; change-limit-ip-split ;;
        16) clearScreen; change-quota-split;;
        17) clearScreen; locked-xray-split;;
        0|00) clearScreen; menu ;;
        *) clearScreen; xsplit ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xsplit
