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

# Membaca File Log
LOG=""
if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
else
    echo "Log file not found!"
    exit 1
fi

mesinssh() {
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
# ==========================================
# Getting
clear
echo " "
echo " "

# Dropbear
echo "----------=[ Dropbear User Login ]=-----------"
echo "ID  |  Username  |  IP Address  |  Time"
echo "----------------------------------------------"
grep -i "dropbear" $LOG | grep -i "Password auth succeeded" > /tmp/login-db.txt

while IFS= read -r line; do
    PID=$(echo "$line" | awk '{print $NF}' | cut -d '[' -f2 | cut -d ']' -f1)
    USER=$(echo "$line" | awk '{print $10}')
    IP=$(echo "$line" | awk '{print $12}')
    TIME=$(echo "$line" | awk '{print $1 " " $2 " " $3}')
    echo "$PID - $USER - $IP - $TIME"
done < /tmp/login-db.txt

echo " "
echo "----------=[ OpenSSH User Login ]=------------"
echo "ID  |  Username  |  IP Address  |  Time"
echo "----------------------------------------------"
grep -i sshd $LOG | grep -i "Accepted password for" > /tmp/login-ssh.txt

while IFS= read -r line; do
    PID=$(echo "$line" | awk '{print $9}' | cut -d '[' -f2 | cut -d ']' -f1)
    USER=$(echo "$line" | awk '{print $9}')
    IP=$(echo "$line" | awk '{print $11}')
    TIME=$(echo "$line" | awk '{print $1 " " $2 " " $3}')
    echo "$PID - $USER - $IP - $TIME"
done < /tmp/login-ssh.txt

# OpenVPN TCP Log
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
    echo ""
    echo "---------=[ OpenVPN TCP User Login ]=---------"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo "----------------------------------------------"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
    cat /tmp/vpn-login-tcp.txt
fi

# OpenVPN UDP Log
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
    echo " "
    echo "---------=[ OpenVPN UDP User Login ]=---------"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo "----------------------------------------------"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
    cat /tmp/vpn-login-udp.txt
fi
echo "----------------------------------------------"
echo ""
}

logs() {
    TEKS="
Log Multi Login SSH
=================
Username: $user
Limit IP: $iplimit
Total Login: $cekcek
Unlock Time: $unlock_time
=================
  [ Time Login ]
$ip_list
=================
The account will be locked for 15 minutes and will be unlocked automatically.
"
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL >/dev/null 2>&1
clear
}

clear
username=$(while IFS=: read -r username _ _ uid _ _ _ _; do
    if [[ $uid -ge 1000 && $username != "nobody" && $username != "root" ]]; then
        echo "$username"
    fi
done < /etc/passwd)
clear

# Membuat direktori jika belum ada
if [ ! -d "/etc/xray/limit/ip/ssh" ]; then
    mkdir -p /etc/xray/limit/ip/ssh
    echo "Direktori /etc/xray/limit/ip/ssh dibuat."
fi

mulog=$(mesinssh)
date=$(date)

for user in ${username[@]}
do
    file_path="/etc/xray/limit/ip/ssh/$user"
    if [ ! -f "$file_path" ]; then
        echo "2" > "$file_path"
        echo "File untuk pengguna $user dibuat dan diisi dengan 2."
    fi

    iplimit=$(cat "$file_path")
    cekcek=$(echo -e "$mulog" | grep "$user" | wc -l)

    # Mendapatkan daftar IP untuk pengguna
    ip_list=$(echo -e "$mulog" | grep "$user" | awk '{print $NF}' | sort | uniq | tr '\n' ', ' | sed 's/, $//')

    # Pastikan user root tidak dikunci
    if [[ $user != "root" && $cekcek -gt $iplimit ]]; then
        systemctl daemon-reload
        systemctl restart ssh
        systemctl restart sshd
        systemctl restart ws
        passwd -l "$user"
        echo "$user dikunci karena melebihi batas login."
        unlock_time=$(date -d "15 minutes" "+%Y-%m-%d %H:%M:%S")
        echo "passwd -u $user" | at now + 15 minutes
        logs >/dev/null 2>&1
        nais=3
    else
        echo > /dev/null
    fi
    sleep 0.1
done

if [[ $nais -gt 1 ]]; then
    clear
else
    echo > /dev/null
fi

# Membersihkan log SSH setelah pemrosesan
echo "" > /tmp/login-db.txt
echo "" > /tmp/login-ssh.txt
echo "" > /tmp/vpn-login-tcp.txt
echo "" > /tmp/vpn-login-udp.txt
echo "" > /var/log/auth.log
# Membersihkan log asli dari file $LOG
echo "" > ${LOG}