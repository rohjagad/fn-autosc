#!/bin/bash


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_PRIMARY="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_FALLBACK="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s --max-time 15 ifconfig.me) # Mendapatkan IP lokal

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
    echo ""
    echo ""
        # Fetch both auth sources at once; first complete valid reply wins (OR logic).
    PERMISSION_TMP=$(mktemp -d) || { echo "Failed to download permissions."; exit 1; }
    (curl -s --max-time 12 "$PERMISSION_PRIMARY" -o "$PERMISSION_TMP/a" 2>/dev/null; touch "$PERMISSION_TMP/a.done") &
    (curl -s --max-time 12 "$PERMISSION_FALLBACK" -o "$PERMISSION_TMP/b" 2>/dev/null; touch "$PERMISSION_TMP/b.done") &
    PERMISSION_DATA=""; end=$((SECONDS+15))
    while [ $SECONDS -lt $end ]; do
        for f in "$PERMISSION_TMP/a" "$PERMISSION_TMP/b"; do
            if [ -f "$f.done" ] && grep -q "###" "$f" 2>/dev/null; then PERMISSION_DATA=$(cat "$f"); break 2; fi
        done
        jobs -rp | grep -q . || break
        sleep 1
    done
    kill $(jobs -rp) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$PERMISSION_TMP"
    [ -z "$PERMISSION_DATA" ] && { echo "Failed to download permissions."; exit 1; }

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep -wF "$LOCAL_IP")
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

# Fungsi untuk menghitung jumlah akun di file http.json
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
xhttp() {
    http=$(countAccounts "/etc/xray/json/upgrade.json")

    clearScreen
    echo -e "${NC}${separator}
        XTLS HTTP UPGRADE
${separator}
HTTP         : ${green}$http${NC}
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
${green}13${NC}. Unlock HTTP Account
${green}14${NC}. Xray Routing Config
${green}15${NC}. Change HTTP IP Limit
${green}16${NC}. Change HTTP Quota Limit
${green}17${NC}. Lock HTTP Account
${green}00${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"

    # Input pilihan dari pengguna
    read -p "Input option: " ophttp || exit 0

    # Menangani pilihan berdasarkan input pengguna
    case $ophttp in
        1|01) clearScreen; add-vmess-http ; xhttp ;;
        2|02) clearScreen; add-vless-http ; xhttp ;;
        3|03) clearScreen; add-trojan-http ; xhttp ;;
        4|04) clearScreen; trial-vmess-http ; xhttp ;;
        5|05) clearScreen; trial-vless-http ; xhttp ;;
        6|06) clearScreen; trial-trojan-http ; xhttp ;;
        7|07) clearScreen; cek-xray-http  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xhttp ;;
        8|08) clearScreen; delete-http ; xhttp ;;
        9|09) clearScreen; extend-http ; xhttp ;;
        10) clearScreen; log-database-xray-http  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xhttp ;;
        11) clearScreen; list-xray-http  ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xhttp ;;
        12) clearScreen; change-id-http ; xhttp ;;
        13) clearScreen; unlock-http ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xhttp ;;
        14) clearScreen; routing-http ; xhttp ;;
        15) clearScreen; change-limit-ip-http ; xhttp ;;
        16) clearScreen; change-quota-http ; xhttp ;;
	17) clearScreen; locked-xray-http ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; xhttp ;;
        0|00) clearScreen; menu ;;
        *) clearScreen; xhttp ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xhttp
