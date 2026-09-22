#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
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
<b>⚠️ X-RAY DELETED ACOUNT ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️  Date     :</b> <code>$DATE</code>
<b>👤 Username :</b> <code>$name</code>
<b>📌 Expired  :</b> <b>$exp2</b>
<b>🛡️  Protokol :</b> <b>$protokol2</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Catatan:</i> Akun Pengguna Telah di unlock oleh owner dan dapat digunakan kembali."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
# Menampilkan daftar akun terkunci untuk di-unlock
locked_files=$(ls /var/log/create/xray/split/*.locked 2>/dev/null)

if [ -n "$locked_files" ]; then
    clear
    echo -e "${NC}${separator}
       UNLOCK X-RAY SPLIT ACCOUNT
${separator}"

    count=0
    for file in $locked_files; do
        username=$(basename "$file" .locked)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep "Protokol:" "$file" | awk '{print $2}')
        count=$((count+1))

        echo -e "${green}$(printf '%02d' $count)${NC}. Username : ${green}$username${NC}"
        echo -e "    Status   : ${red}Locked${NC}"
        echo -e "    UUID     : $uid"
        echo -e "    Expired  : $exp"
        echo -e "    Protocol : $protokol"
        echo -e "${blue_sep}"
    done
    echo -e "${orange}Press [Ctrl + C] to exit${NC}"
    echo -e "${separator}"

    read -p "Input Username to Unlock: " name
else
    clear
    echo "No locked accounts found to unlock."
    exit 1
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/split/${name}.locked | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/split/${name}.locked | awk '{print $3}')
protokol2=$(grep "Protokol:" /var/log/create/xray/split/${name}.locked | awk '{print $2}')

clear

echo -e "${NC}${separator}
       UNLOCK ACCOUNT DETAILS
${separator}
Date     : $(date)
Username : ${green}$name${NC}
Expired  : $exp2
UUID     : $uuid
Protocol : $protokol2
Status   : ${green}Unlocked${NC}
${separator}"

# Konfirmasi dari pengguna sebelum melakukan unlock
read -p "Apakah Anda yakin ingin unlock akun ini? (y/n): " confirm

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Logika melakukan unlock
    if [ "$protokol2" == "Vmess" ]; then
        sed -i '/#vmess$/a\### '"$name $exp2"'\
        },{"id": "'""$uuid""'","alterid": 0,"email": "'""$name""'"' /etc/xray/json/split.json
    elif [ "$protokol2" == "Vless" ]; then
        sed -i '/#vless$/a\### '"$name $exp2"'\
        },{"id": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/split.json
    elif [ "$protokol2" == "Trojan" ]; then
        sed -i '/#trojan$/a\### '"$name $exp2"'\
        },{"password": "'""$uuid""'","email": "'""$name""'"' /etc/xray/json/split.json
    else
        echo "Protokol tidak dikenal"
    fi

    mv /var/log/create/xray/split/${name}.locked /var/log/create/xray/split/${name}.log
     systemctl daemon-reload
     systemctl restart xray@split
    # Send Notif Telegram
    send_log

    clear
    echo -e "
    Detail Unlock X-Ray WS
    ======================

    Date: $(date)
    Username: $name
    Expired on: $exp2
    UUID: $uuid
    Protokol: $protokol2
    Status: Unlock
    =======================
    "
else
    echo "Proses unlock dibatalkan."
fi