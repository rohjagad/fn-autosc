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
# Detail Hosting
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
clear

# WebSocket transport, served by Xray.
#
# Xray runs /etc/xray/json/ws.json directly - the template installer/xray.sh has
# already deployed - so there is nothing to download and no second copy: the file
# the account scripts edit is the file the service runs. The inbound ports are the
# ones V2Ray used, so nginx needs no change, and because Xray serves this
# transport its api inbound on 127.0.0.1:10080 now answers "xray api
# statsonline" - which is what makes the WS IP limit enforceable.

# Give the config a real UUID in place of the template placeholder.
sed -i "s/rerechan-store/$(xray uuid)/g" /etc/xray/json/ws.json

# Log file (the config writes /var/log/xray/ws.log).
mkdir -p /var/log/xray
touch /var/log/xray/ws.log
chmod 755 /var/log/xray/ws.log
chown root:root /var/log/xray/ws.log

# Service
systemctl daemon-reload
systemctl enable xray@ws
systemctl restart xray@ws

# Setup Port SSH
sudo sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
systemctl daemon-reload
systemctl restart ssh

# Konfigurasi tambahan
echo -e "PS1='\033[1;34m\]╭───\[\033[1;31m\]≼\[\033[1;33m\]FN AutoSC\[\033[1;34m\]•\[\033[1;30m\]\w\[\033[1;31m\]≽
\[\033[1;34m\]╰──╼\[\033[1;31m\]✠\[\033[1;32m\] \033[0m'" >> /root/.bashrc

# menghapus file dump
rm -f /root/ws.sh
