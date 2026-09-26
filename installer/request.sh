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
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL") || { echo "Failed to download permissions."; exit 1; }

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

hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main/udp"

clear

# Create Directory
mkdir -p /root/udp-request

# Go To Directory
cd /root/udp-request

# Copy Core File
wget --no-check-certificate -O /root/udp-request/udp-request-linux-amd64 https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/udp-request-linux-amd64 || wget --no-check-certificate ${hosting}/udp-request-linux-amd64

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

# Penjaga rule: udp-request menyisipkan rule-nya di paling atas setiap kali
# service-nya (re)start, jadi dua kebocoran harus di-assert ulang oleh timer:
#  1. SNAT lebar (POSTROUTING) yang mengenai alamat host sendiri;
#  2. capture UDP wildcard (PREROUTING dpts:1:8988 dan dpts:8990:65535
#     -> 8989, lalu dpts:1:65535 -> 36711) yang menelan handshake layanan UDP
#     milik panel sendiri: WireGuard 51820, OpenVPN UDP 2200, IPsec/IKE
#     500/4500 dan L2TP 1701. iptables first-match, dan diverifikasi live -
#     handshake klien WireGuard mendarat di rule capture, tunnel tidak pernah
#     naik; begitu RETURN dipasang di atasnya, tunnel langsung jalan (ping ke
#     10.66.66.1 dan egress lewat VPS).
cat > /usr/local/bin/udp-request-fixnet.sh <<-FIXSH
#!/bin/bash
ip_nat="$ip_nat"
[ -n "\$ip_nat" ] && { iptables -t nat -D POSTROUTING -s "\$ip_nat" -j RETURN 2>/dev/null; iptables -t nat -I POSTROUTING 1 -s "\$ip_nat" -j RETURN; }
for p in 51820 2200 500 4500 1701; do
    while iptables -t nat -D PREROUTING -p udp --dport "\$p" -j RETURN 2>/dev/null; do :; done
    iptables -t nat -I PREROUTING 1 -p udp --dport "\$p" -j RETURN
done
exit 0
FIXSH
chmod +x /usr/local/bin/udp-request-fixnet.sh
cat > /etc/systemd/system/udp-request-fixnet.service <<-FIXSVC
[Unit]
Description=Keep the panel's own UDP services out of udp-request's capture and SNAT
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/udp-request-fixnet.sh
FIXSVC
cat > /etc/systemd/system/udp-request-fixnet.timer <<-FIXTMR
[Unit]
Description=Re-assert the host SNAT exclusion and the panel's UDP service bypasses every 15 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=15s
# default AccuracySec is 1min, which left the panel's own UDP services captured
# for up to a minute after every udp-request restart
AccuracySec=1s

[Install]
WantedBy=timers.target
FIXTMR
systemctl daemon-reload
systemctl enable --now udp-request-fixnet.timer

# Delete File Dump
rm -f /root/request.sh

