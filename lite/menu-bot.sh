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

    output
clear

botmenu() {

termbot() {
install() {
# [ Repository Bot Telegram ]
link="https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/1.23/bot.zip"

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
Success Deleted Bot Terminal"
}

restart() {
systemctl daemon-reload
systemctl restart bot
clear
echo "
Success Reboot Bot Terminal"
}

menubot() {
clear
edussh_service=$(systemctl status bot | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
ws="\e[1;32m[ ON ]\033[0m"
else
ws="\e[1;31m[ OFF ]\033[0m"
fi
clear
echo -e "
<= Menu Bot Terminal =>
=======================
Bot: $ws

1. Install Bot Terminal
2. Uninstall Bot Terminal
3. Restart Service Bot Terminal
0. Back To Default Menu Panel
=======================
Press CTRL + C to Exit
"
read -p "Input Option: " opw
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
Your Data Bot Notirication
===========================
API Bot: $api
Chatid Own: $itd
===========================
"
}

add() {
clear
echo -e "
===================
[ 设置机7器人通知 ]
===================
"
read -p "API Key Bot: " api
read -p "Your Chat ID: " itd
clear
echo -e "
Information
==============================
API Bot: $api
Chatid : $itd
==============================
"
read -p "Is the data above correct? (y/n): " opw
case $opw in
y) clear ; lanjut ;;
n) clear ; add ;;
*) clear ; add ;;
esac
}

rpot() {
echo "
Report Bug To
=====================
Telegram:

- FN AutoSC
- @farell_aditya_ardian
- @PR_Aiman
=====================
Email:

- widyabakti02@gmail.com
=====================

Thanks For Use My Script
"
}

mna() {
echo -e "
======================
[   菜单设置机器人   ]
======================

1. Setup Bot Notification
2. Setup Bot Panel All Menu
3. Setup Bot Terminal Server
4. Report Bug On Script
======================
Press CTRL + C to exit
"
read -p "Input Option: " apws
case $apws in
1) clear ; add ;;
2) clear ; clear ; echo -e "\n Coming Soon On 1.19?" ;;
3) clear ; termbot ;;
4) clear ; rpot ;;
*) clear ; mna ;;
esac
}

mna
}

botmenu