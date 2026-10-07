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

clear
echo ""
echo ""
botmenu() {

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

termbot() {
install() {
# [ Repository Bot Telegram ]
# The bot bundle is vendored in this repository (other/bot.zip), not fetched
# from rohjagad/FN-API: that repository is the provider's own package and is kept
# as a reference only (is-decision.md section 18).
link="https://raw.githubusercontent.com/rohjagad/fn-autosc/main/other/bot.zip"

# [ Membersihkan layar ]
clear
echo ""
echo ""
# [ File lokasi API Key dan Chat ID ]
api_file="/etc/funny/.keybot"
id_file="/etc/funny/.chatid"

# [ Memeriksa apakah file API Key dan Chat ID ada ]
if [[ -f "$api_file" && -f "$id_file" ]]; then
    api=$(cat "$api_file")
    itd=$(cat "$id_file")
else
    echo -e "
${separator}
[ 设置机器人通知 ]
${separator}
"
    read -p "API Key Bot: " api || return
    [ -z "$api" ] && { echo "API Key cannot be empty."; sleep 2; return; }
    read -p "Your Chat ID: " itd || return
    if ! [[ "$itd" =~ ^-?[0-9]+$ ]]; then
        echo "Chat ID must be a numeric value (e.g. 123456789 or -100123456789)."
        sleep 2
        return 1
    fi
    
    # [ Menyimpan API Key dan Chat ID ke file ]
    echo "$api" > "$api_file"
    echo "$itd" > "$id_file"
fi

clear
echo ""
echo ""
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
StartLimitIntervalSec=120
StartLimitBurst=30

[Service]
ExecStart=/usr/bin/node /usr/bin/bot/server.js
WorkingDirectory=/usr/bin/bot
Restart=always
RestartSec=3s
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
echo ""
echo ""
# [ Menampilkan Output ]
echo -e "
Success Install Bot Terminal
${separator}

Your Database
Chat ID : $itd
Api Bot : $api

Just Check Your Bot Terminal
${separator}
"
}

hapus() {
systemctl stop bot
systemctl disable bot
rm -fr /etc/systemd/system/bot.service
rm -fr /usr/bin/bot
clear
echo ""
echo ""
echo "
Terminal Bot Uninstalled Successfully"
}

restart() {
systemctl daemon-reload
systemctl restart bot
clear
echo ""
echo ""
echo "
Terminal Bot Restarted Successfully"
}

menubot() {
clear
echo ""
echo ""
edussh_service=$(systemctl status bot 2>/dev/null | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
    ws="${green}ON${NC}"
else
    ws="${red}OFF${NC}"
fi
clear
echo ""
echo ""
echo -e "${NC}${separator}
        TERMINAL BOT MENU
${separator}
Bot          : $ws
${blue_sep}
${green}1${NC}. Install Terminal Bot
${green}2${NC}. Uninstall Terminal Bot
${green}3${NC}. Restart Terminal Bot
${green}0${NC}. Back to Bot Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opw || exit 0
case $opw in
1) clear ; install ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menubot ;;
2) clear ; hapus ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menubot ;;
3) restart ; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; menubot ;;
0|00) clear ; mna ;;
*) menubot ;;
esac
}

menubot
}

clear
echo ""
echo ""
lanjut() {
rm -fr /etc/funny/.chatid
rm -fr /etc/funny/.keybot
echo "$api" > /etc/funny/.keybot
echo "$itd" > /etc/funny/.chatid
chmod 600 /etc/funny/.keybot /etc/funny/.chatid 2>/dev/null || true
clear
echo ""
echo ""
echo -e "Telegram Bot Configuration
${separator}
Bot API Key: $api
Owner Chat ID: $itd
${separator}
"
}

havecreds() {
# Notifications and auto backup both reuse the credentials written by
# "Set Up Bot Credentials" - they never ask for them again.
if [ -s /etc/funny/.keybot ] && [ -s /etc/funny/.chatid ]; then
    return 0
fi
clear
echo ""
echo ""
echo -e "${separator}
 Bot Credentials Not Set
${separator}
 Choose "1. Set Up Bot Credentials" first,
 then come back to this menu.
${separator}
"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
return 1
}

creds() {
# The single place the bot credentials are entered or changed. The registered
# values are shown first; pressing ENTER on a field keeps the registered value.
clear
echo ""
echo ""
cur_id=$(cat /etc/funny/.chatid 2>/dev/null)
cur_key=$(cat /etc/funny/.keybot 2>/dev/null)
echo -e "
${separator}
[ Bot Credentials ]
${separator}
 Registered Chat ID : ${cur_id:-<not set>}
 Registered API Key : ${cur_key:-<not set>}

 Press ENTER on a field to keep its value.
"
read -p "Telegram Chat ID: " itd || return
read -p "Bot API Key     : " api || return
[ -z "$itd" ] && itd="$cur_id"
if [ -n "$itd" ] && ! [[ "$itd" =~ ^-?[0-9]+$ ]]; then
    echo "Chat ID must be numeric. Aborting."
    return 1
fi
[ -z "$api" ] && api="$cur_key"
if [ -z "$itd" ] || [ -z "$api" ]; then
    clear
    echo ""
    echo ""
    echo -e "${separator}
 Both values are required.
${separator}
"
    sleep 2
    clear ; creds
    return
fi
clear
echo ""
echo ""
echo -e "Information
${separator}
Bot API Key: $api
Chat ID    : $itd
${separator}
"
read -p "Is the data above correct? (y/n): " opw || return
case $opw in
y) clear ; lanjut ;;
n) clear ; creds ;;
*) clear ; creds ;;
esac
}

notif() {
# Uses the saved credentials; sends one test message to prove it works.
havecreds || return
local key id resp
key=$(cat /etc/funny/.keybot 2>/dev/null)
id=$(cat /etc/funny/.chatid 2>/dev/null)
clear
echo ""
echo ""
echo "Sending a test notification to Telegram..."
resp=$(curl -4 -s --max-time 15 -d "chat_id=$id" \
    --data-urlencode "text=[ FN AutoSC ] Notification setup complete - the bot is configured correctly." \
    "https://api.telegram.org/bot$key/sendMessage")
clear
echo ""
echo ""
if echo "$resp" | grep -q '"ok":true'; then
    echo -e "
${separator}
 Bot Notifications
${separator}
 Status  : enabled
 Chat ID : $id
 A test message has been sent to that chat.
${separator}
"
else
    echo -e "
${separator}
 Bot Notifications - FAILED
${separator}
 Telegram replied:
 $resp

 Check the API key and chat ID (option 1).
${separator}
"
fi
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

setbotup() {
# Uses the saved credentials; sets how often the scheduled backup runs,
# so the archive is delivered to Telegram automatically.
havecreds || return
short_sep=$(rainbow_sep '-----------------')
cronline=$(grep 'flock -n /tmp/backup.lock backup' /etc/crontab 2>/dev/null | head -n 1)
cur="not set"
if echo "$cronline" | grep -q '0 \*/\([0-9][0-9]*\) '; then
    cur="every $(echo "$cronline" | sed -n 's/.*0 \*\/\([0-9][0-9]*\) .*/\1/p') hour"
elif echo "$cronline" | grep -q '0 0,6,12,18'; then
    cur="every 6 hour"
elif echo "$cronline" | grep -q '0 \* '; then
    cur="every 1 hour"
fi
clear
echo ""
echo ""
echo -e "${separator}
SETUP AUTO BACKUP
${short_sep}
${blue_sep}
Current interval  : $cur"
read -p "New interval      : " hours || return
[ -z "$hours" ] && return
while ! [[ "$hours" =~ ^[1-9][0-9]*$ ]] || [ "$hours" -gt 24 ]; do
    echo -e "\033[0;31mValue must be a whole number 1-24.\033[0m"
    read -p "New interval      : " hours || return
    [ -z "$hours" ] && return
done
sed -i '/flock -n \/tmp\/backup.lock backup/d' /etc/crontab
echo "0 */$hours * * * root flock -n /tmp/backup.lock backup" >> /etc/crontab
systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
echo -e "${blue_sep}
Auto backup set to every $hours hour
${separator}"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

rpot() {
echo -e "${NC}${separator}
          REPORT SCRIPT BUG
${separator}
Telegram:
- FN AutoSC: https://t.me/rohcuan
${blue_sep}
Thanks for using this script
"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

mna() {
clear
echo ""
echo ""
echo -e "${NC}${separator}
        TELEGRAM BOT MENU
${separator}
${green}1${NC}. Set Up Bot Credentials
${green}2${NC}. Set Up Bot Notifications
${green}3${NC}. Set Up Bot Auto Backup
${green}4${NC}. Terminal Bot Menu
${green}5${NC}. Report Script Bug
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " apws || exit 0
case $apws in
1) clear ; creds ; mna ;;
2) clear ; notif ; mna ;;
3) clear ; setbotup ; mna ;;
4) clear ; termbot ; mna ;;
5) clear ; rpot ; mna ;;
0|00) clear ; menu ;;
*) clear ; mna ;;
esac
}

mna
}

botmenu
