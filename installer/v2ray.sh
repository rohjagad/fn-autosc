#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohfn-autosc-auth/1.23/izin.txt"
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

# Detail Hosting
hosting="https://raw.githubusercontent.com/rohjagad/rohfn-autosc/1.23"
clear

# Mengkonfigurasi V2ray default
apt install v2ray -y
apt install zip -y
apt insfall unzip -y

# Konfigurasi Host Github
echo "199.232.68.133 raw.githubusercontent.com" >> /etc/hosts
echo "199.232.68.133 user-images.githubusercontent.com" >> /etc/hosts
echo "199.232.68.133 avatars2.githubusercontent.com" >> /etc/hosts
echo "199.232.68.133 avatars1.githubusercontent.com" >> /etc/hosts
echo "199.232.68.133 objects.githubusercontent.com" >> /etc/hosts

# Mengganti Core V2ray
rm -f /usr/bin/v2ray
cd /root
mkdir .a
cd .a
wget -O z.zip "${hosting}/v2ray/v2ray-linux-64.zip"
unzip z.zip
mv v2ray /usr/bin/v2ray
cp *.dat /etc/v2ray
chmod +x /usr/bin/v2ray
chmod +x /etc/v2ray/*.dat

# Mengambil json
cd /etc/xray/json
cat ws.json > /etc/v2ray/config.json

# Mengganti UUID Default V2ray
sed -i "s/rerechan-store/$(xray uuid)/g" /etc/v2ray/config.json

# Mengganti Path Log File
cd /etc/v2ray
find $(pwd) -type f -exec sed -i 's|/var/log/xray/ws.log|/var/log/v2ray/access.log|g' {} +

# Mengganti Service
cd /lib/systemd/system
sed -i 's|DynamicUser=true|User=root|g' v2ray.service
sed -i 's|/usr/bin/v2ray -config /etc/v2ray/config.json|/usr/bin/v2ray run -c /etc/v2ray/config.json|g' v2ray.service

# Mengganti Outbound Default
# Mengambil Lokasi Xray Config
XRAY_CONFIG="/etc/v2ray/config.json"

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/v2ray/config.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/v2ray/config.json
TEXT="
    \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
         \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\" : true,
      \"statsOutboundDownlink\" : true
    }
  }
}"
# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Permission File Json
cd /etc/v2ray
chmod 755 config.json

# Permision Log
rm -fr /var/log/v2ray
mkdir -p /var/log/v2ray
touch /var/log/v2ray/access.log
chmod 755 /var/log/v2ray/access.log
chown root:root /var/log/v2ray/access.log

# Menjalanlan service
systemctl daemon-reload
systemctl enable v2ray
systemctl start v2ray
systemctl restart v2ray

# Setup Port SSH
sudo sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
systemctl daemon-reload
systemctl restart ssh

# Konfigurasi tambahan
echo -e "PS1='\033[1;34m\]╭───\[\033[1;31m\]≼\[\033[1;33m\]FN PROJECT\[\033[1;34m\]•\[\033[1;30m\]\w\[\033[1;31m\]≽
\[\033[1;34m\]╰──╼\[\033[1;31m\]✠\[\033[1;32m\] \033[0m'" >> /root/.bashrc
source /root/.bashrc

# menghapus file dump
rm -f /root/v2ray.sh