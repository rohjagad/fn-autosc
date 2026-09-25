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
        echo "Your IP is not in the database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"
    }

clear

botmenu() {

red='\033[0;31m'
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

termbot() {
install() {
# [ Repository Bot Telegram ]
link="https://raw.githubusercontent.com/rohjagad/FN-API/main/bot.zip"

# [ Membersihkan layar ]
clear

# [ File lokasi API Key dan Chat ID ]
api_file="/etc/funny/.keybot"
id_file="/etc/funny/.chatid"

# [ Memeriksa apakah file API Key dan Chat ID ada ]
if [[ -f "$api_file" && -f "$id_file" ]]; then
    api=$(cat "$api_file")
    itd=$(cat "$id_file")
else
    echo -e "
===================
[ 设置机器人通知 ]
===================
"
    read -p "API Key Bot: " api
    read -p "Your Chat ID: " itd
    
    # [ Menyimpan API Key dan Chat ID ke file ]
    echo "$api" > "$api_file"
    echo "$itd" > "$id_file"
fi

clear

# [ Menginstall Bot ]
cd /usr/bin
wget -O bot.zip "${link}"
yes A | unzip bot.zip
rm -fr bot.zip
cd /usr/bin/bot
npm install

# [ Membuat Konfigurasi API Bot ]
cat > /usr/bin/bot/config.json << EOF
{
    "authToken": "$api",
    "owner": $itd
}
EOF

# [ Menginstall Service ]
cat > /etc/systemd/system/bot.service << END
[Unit]
Description=Service for bot terminal
After=network.target

[Service]
ExecStart=/usr/bin/node /usr/bin/bot/server.js
WorkingDirectory=/usr/bin/bot
Restart=always
User=root

[Install]
WantedBy=multi-user.target
END

# [ Menjalankan Service ]
systemctl daemon-reload
systemctl enable bot
systemctl start bot
systemctl restart bot

# [ Membersihkan Layar ]
clear

# [ Menampilkan Output ]
echo -e "
Success Install Bot Terminal
============================

Your Database
Chat ID : $itd
Api Bot : $api

Just Check Your Bot Terminal
============================
"
}

hapus() {
systemctl stop bot
systemctl disable bot
rm -fr /etc/systemd/system/bot.service
rm -fr /usr/bin/bot
clear
echo "
Terminal Bot Uninstalled Successfully"
}

restart() {
systemctl daemon-reload
systemctl restart bot
clear
echo "
Terminal Bot Restarted Successfully"
}

menubot() {
clear
edussh_service=$(systemctl status bot 2>/dev/null | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
    ws="${green}ON${NC}"
else
    ws="${red}OFF${NC}"
fi
clear
echo -e "${NC}${separator}
        TERMINAL BOT MENU
${separator}
Bot          : $ws
${blue_sep}
${green}1${NC}. Install Terminal Bot
${green}2${NC}. Uninstall Terminal Bot
${green}3${NC}. Restart Terminal Bot
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opw
case $opw in
1) clear ; install ;;
2) clear ; hapus ;;
3) restart ;;
0) menu ;;
*) menubot ;;
esac
}

menubot
}

clear

lanjut() {
rm -fr /etc/funny/.chatid
rm -fr /etc/funny/.keybot
echo "$api" > /etc/funny/.keybot
echo "$itd" > /etc/funny/.chatid
clear
echo -e "
Telegram Bot Configuration
==========================
Bot API Key: $api
Owner Chat ID: $itd
==========================
"
}

add() {
clear
echo -e "
======================
[ Telegram Bot Setup ]
======================
"
read -p "Bot API Key: " api
read -p "Telegram Chat ID: " itd
clear
echo -e "
Information
==============================
Bot API Key: $api
Chat ID    : $itd
==============================
"
read -p "Is the data above correct? (y/n): " opw
case $opw in
y) clear ; lanjut ;;
n) clear ; add ;;
*) clear ; add ;;
esac
}

setbotup() {
# The bot credentials are the ones option 1 writes; this entry also guarantees
# the scheduled backup exists, so choosing it is all that is needed for the
# archive to be delivered to Telegram automatically.
add
grep -q 'flock -n /tmp/backup.lock backup' /etc/crontab 2>/dev/null || \
    echo '0 0,6,12,18 * * * root flock -n /tmp/backup.lock backup' >> /etc/crontab
clear
echo -e "
=========================================
 Bot Auto Backup
=========================================
 Chat ID  : $(cat /etc/funny/.chatid 2>/dev/null)
 Schedule : 0 0,6,12,18 (4x daily)
 Delivery : Telegram document
=========================================
"
}

rpot() {
echo -e "${NC}${separator}
          REPORT SCRIPT BUG
${separator}
Telegram:
- FN AutoSC
- @farell_aditya_ardian
- @PR_Aiman
${blue_sep}
Email:
- widyabakti02@gmail.com
${separator}

Thanks for using this script
"
}

mna() {
clear
echo -e "${NC}${separator}
        TELEGRAM BOT MENU
${separator}
${green}1${NC}. Set Up Bot Notifications
${green}2${NC}. Set Up Bot Auto Backup
${green}3${NC}. Terminal Bot Menu
${green}4${NC}. Report Script Bug
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " apws
case $apws in
1) clear ; add ;;
2) clear ; setbotup ;;
3) clear ; termbot ;;
4) clear ; rpot ;;
*) clear ; mna ;;
esac
}

mna
}

botmenu