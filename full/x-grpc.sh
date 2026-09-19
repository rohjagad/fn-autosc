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

# Fungsi untuk menghitung jumlah akun di file grpc.json
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
xgrpc() {
    grpc=$(countAccounts "/etc/xray/json/grpc.json")

    clearScreen
    echo -e "${NC}${separator}
            XTLS gRPC
${separator}
gRPC         : ${green}$grpc${NC}
${blue_sep}
${purple}MENU CREATE${NC}
${green}01${NC}. Create Account Vmess
${green}02${NC}. Create Account Vless
${green}03${NC}. Create Account Trojan
${blue_sep}
${purple}MENU TRIAL${NC}
${green}04${NC}. Trial Account Vmess
${green}05${NC}. Trial Account Vless
${green}06${NC}. Trial Account Trojan
${blue_sep}
${purple}OTHER SERVICE${NC}
${green}07${NC}. Cek User Login
${green}08${NC}. Delete Account
${green}09${NC}. Extend Expired
${green}10${NC}. Cek Log Database
${green}11${NC}. List Database Account
${green}12${NC}. Change UUID / Password
${green}13${NC}. Unlock Account gRPC
${green}14${NC}. Routing X-Ray gRPC
${green}15${NC}. Change Limit IP gRPC
${green}16${NC}. Change Quota gRPC
${green}17${NC}. Locked Account gRPC
${separator}

${orange}Press [Ctrl + C] to exit${NC}"

    # Input pilihan dari pengguna
    read -p "Input option: " opgrpc

    # Menangani pilihan berdasarkan input pengguna
    case $opgrpc in
        1) clearScreen; add-vmess-grpc ;;
        2) clearScreen; add-vless-grpc ;;
        3) clearScreen; add-trojan-grpc ;;
        4) clearScreen; trial-vmess-grpc ;;
        5) clearScreen; trial-vless-grpc ;;
        6) clearScreen; trial-trojan-grpc ;;
        7) clearScreen; cek-xray-grpc ;;
        8) clearScreen; delete-grpc ;;
        9) clearScreen; extend-grpc ;;
        10) clearScreen; log-database-xray-grpc ;;
        11) clearScreen; list-xray-grpc ;;
        12) clearScreen; change-id-grpc ;;
        13) clearScreen; unlock-grpc ;;
        14) clearScreen; routing-grpc ;;
        15) clearScreen; change-limit-ip-grpc ;;
        16) clearScreen; change-quota-grpc ;;
	17) clearScreen; locked-xray-grpc ;;
        *) clearScreen; xgrpc ;;  # Jika input tidak valid, ulangi menu
    esac
}

# Menjalankan fungsi utama
xgrpc
