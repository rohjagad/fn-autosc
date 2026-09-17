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

hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/1.23/udp"

clear

# Create Directory
mkdir -p /root/udp-request

# Go To Directory
cd /root/udp-request

# Copy Core File
wget --no-check-certificate ${hosting}/udp-request-linux-amd64 >> /dev/null 2>&1

# Create Json File
cat > /root/udp-request/config.json <<-JSON
{
  "listen": ":36711",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
JSON

# Permision
cd /root/udp-request
chmod +x udp-request-linux-amd64
chmod +x config.json
cd

# Detail Information
ip_nat=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n 1p)
interface=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | grep "$ip_nat" | awk {'print $NF'})
public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<<"$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")

# Create Service
cd /etc/systemd/system
cat > udp-request.service <<-SERV
[Unit]
Description=UDP Request By FN AutoSC
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/udp-request/
ExecStart=/root/udp-request/udp-request-linux-amd64 -ip=$public_ip -net=$interface -mode=system
ExecStartPost=/bin/bash -c 'sleep 2; iptables -t nat -D POSTROUTING -s $ip_nat -j RETURN 2>/dev/null; iptables -t nat -I POSTROUTING 1 -s $ip_nat -j RETURN; exit 0'
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
SERV

# Menyalakan Service
systemctl daemon-reload
systemctl enable udp-request
systemctl start udp-request

# Penjaga rule host agar tidak kena SNAT udp-request bila service restart berulang
cat > /etc/systemd/system/udp-request-fixnet.service <<-FIXSVC
[Unit]
Description=Keep host IP out of udp-request SNAT
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'iptables -t nat -D POSTROUTING -s $ip_nat -j RETURN 2>/dev/null; iptables -t nat -I POSTROUTING 1 -s $ip_nat -j RETURN; exit 0'
FIXSVC
cat > /etc/systemd/system/udp-request-fixnet.timer <<-FIXTMR
[Unit]
Description=Re-assert host SNAT exclusion every 15 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=15s

[Install]
WantedBy=timers.target
FIXTMR
systemctl daemon-reload
systemctl enable --now udp-request-fixnet.timer

# Delete File Dump
rm -f /root/request.sh

