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

# Function Send Log
send_log() {
    CHATID=$(cat /etc/funny/.chatid)
    KEY=$(cat /etc/funny/.keybot)
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    TIME="10"
    DATE=$(date +"%Y-%m-%d %H:%M:%S")

    TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>⚠️ X-RAY WS Change UUID ⚠️</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>🗓️ Date          :</b> <code>$DATE</code>
<b>👤 Username     :</b> <code>$user</code>
<b>📌 Old UUID     :</b> <b>$old</b>
<b>📌 New UUID     :</b> <b>$new</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Note:</i> The account UUID has been successfully changed. Modification has been reflected in the database."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Colors for styling
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fetch all usernames and UUIDs
usernames=($(grep "^### " /etc/v2ray/config.json | awk '{print $2}' | sort | uniq))

# Clear screen and display header
clear
echo -e "${CYAN}========================================="
echo -e "${GREEN}          Change UUID X-ray Ws"
echo -e "${CYAN}========================================="
echo -e "${YELLOW} Username      |       UUID"
echo -e "${CYAN}========================================="

# Display usernames and UUIDs
for user in "${usernames[@]}"; do
    uid=$(grep "${user}" /etc/v2ray/config.json | awk -F'"id": "' '{print $2}' | awk -F'"' '{print $1}' | sort | uniq | strings)
    echo -e "${GREEN} $user      |       $uid"
done

echo -e "${CYAN}========================================="
echo -e "${RED} Press CTRL + C to exit"
echo -e "${CYAN}=========================================${NC}"

# Prompt user input for username and validate
while true; do
    read -p "Input Username: " user
    if [[ -z "$user" || ! -f "/var/log/create/xray/ws/${user}.log" ]]; then
        echo -e "${RED}Invalid username! Please try again.${NC}"
    else
        break
    fi
done

# Prompt for new UUID, generate if empty
read -p " Input New UUID (or press Enter to auto-generate): " new
if [[ -z "$new" ]]; then
    new=$(xray uuid)
    echo -e "Generated new UUID: $new"
    sleep 2
fi
clear

# GET OLD UUID
old=$(grep "${user}" /etc/v2ray/config.json | awk -F'"id": "' '{print $2}' | awk -F'"' '{print $1}' | sort | uniq | strings)

# Replace old UUID with new UUID in necessary files
sed -i "s|\"id\": \"${old}\"|\"id\": \"${new}\"|" /etc/xray/json/*.json
sed -i "s|\"password\": \"${old}\"|\"password\": \"${new}\"|" /etc/xray/json/*.json
sed -i "s|UUID   : $old|UUID   : $new|" /var/log/create/xray/ws/${user}.log
sed -i 's/${old}/${new}/g' /var/log/create/xray/ws/${user}.log

# Restart All Service
systemctl daemon-reload
systemctl restart v2ray

# Log Information
send_log

clear
# Confirmation message with updated information
echo -e "${CYAN}========================================="
echo -e "${GREEN} UUID Update Successful!"
echo -e "${CYAN}========================================="
echo -e "${YELLOW} Username      |       New UUID"
echo -e "${CYAN}========================================="
echo -e "${GREEN} $user      |       $new"
echo -e "${CYAN}=========================================${NC}"