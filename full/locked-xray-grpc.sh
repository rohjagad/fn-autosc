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
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"
    }

    output
clear

# Colors
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
red='\033[0;31m'
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


# Function Send Log
send_log() {
    CHATID=$(cat /etc/funny/.chatid)
    KEY=$(cat /etc/funny/.keybot)
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    TIME="10"
    DATE=$(date +"%Y-%m-%d %H:%M:%S")

    TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>⚠️ X-RAY gRPC LOCKED ACOUNT ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️  Date     :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$name</code>
<b>📌 Expired  :</b> <b>$exp2</b>
<b>🛡️  Protokol :</b> <b>$protokol2</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah di locked oleh owner dan tidak dapat digunakan."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
# Menampilkan daftar akun aktif untuk di-lock
locked_files=$(ls /var/log/create/xray/grpc/*.log 2>/dev/null)

if [ -n "$locked_files" ]; then
    clear
    echo -e "${NC}${separator}
        LOCK X-RAY gRPC ACCOUNT
${separator}"

    count=0
    for file in $locked_files; do
        username=$(basename "$file" .log)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep "Protokol:" "$file" | awk '{print $2}')
        count=$((count+1))

        echo -e "${green}$(printf '%02d' $count)${NC}. Username : ${green}$username${NC}"
        echo -e "    Status   : ${green}Active${NC}"
        echo -e "    UUID     : $uid"
        echo -e "    Expired  : $exp"
        echo -e "    Protocol : $protokol"
        echo -e "${blue_sep}"
    done
    echo -e "${orange}Press [Ctrl + C] to exit${NC}"
    echo -e "${separator}"

    read -p "Input Username to Lock: " name
else
    clear
    echo "No active accounts found to lock."
    exit 1
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/grpc/${name}.log | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/grpc/${name}.log | awk '{print $3}')
protokol2=$(grep "Protokol:" /var/log/create/xray/grpc/${name}.log | awk '{print $2}')

clear

echo -e "${NC}${separator}
        LOCK ACCOUNT DETAILS
${separator}
Date     : $(date)
Username : ${green}$name${NC}
Expired  : $exp2
UUID     : $uuid
Protocol : $protokol2
Status   : ${red}Locked${NC}
${separator}"

# Langsung lakukan unlock jika username valid
if [ "$protokol2" == "Vmess" ]; then
    sed -i '/#vmess$/a\### '"$name $exp2"'\
    },{"id": "'""$uuid""'","alterid": 0,"email": "'""$name""'"' /etc/xray/json/grpc.json
elif [ "$protokol2" == "Vless" ]; then
    sed -i '/#vless$/a\### '"$name $exp2"'\
    },{"id": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/grpc.json
elif [ "$protokol2" == "Trojan" ]; then
    sed -i '/#trojan$/a\### '"$name $exp2"'\
    },{"password": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/grpc.json
else
    echo "Protokol tidak dikenal"
fi

    exp=$(grep -wE "^### $name" "/etc/xray/json/grpc.json" | cut -d ' ' -f 3 | sort | uniq)
    sed -i "/### $user $exp/ {N;d}" /etc/xray/json/grpc.json
mv /var/log/create/xray/grpc/${name}.log /var/log/create/xray/grpc/${name}.locked
systemctl daemon-reload
systemctl restart xray@grpc
# Send Notif Telegram
send_log

clear
echo -e "
Detail Locked X-Ray gRPC
======================

Date: $(date)
Username: $name
Expired on: $exp2
UUID: $uuid
Protokol: $protokol2
Status: Locked
======================
"
