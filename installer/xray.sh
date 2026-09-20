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

# Detail Hosting
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/1.23"
clear

# Menginstall Core
xver="25.3.6"
bash -c "$(curl -L https://raw.githubusercontent.com/rohjagad/Xray-install/main/install-release.sh)" @ install -u www-data --version $xver
rm -fr /etc/systemd/system/xray.service
rm -fr /etc/systemd/system/xray.service.d
rm -fr /etc/systemd/system/xray@.service
rm -fr /etc/systemd/system/xray@.service.d
cat> /etc/systemd/system/xray@.service << MLBB
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/json/%i.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
MLBB
systemctl daemon-reload
clear

# Mengcopy Json
mkdir -p /etc/xray/json
cd /etc/xray/json
wget --no-check-certificate ${hosting}/json/ws.json >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/json/upgrade.json >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/json/split.json >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/json/grpc.json >> /dev/null 2>&1

# Mengubah Permision Json
chmod +x ws.json
chmod +x upgrade.json
chmod +x split.json
chmod +x grpc.json

# Membuat File Log
mkdir -p /var/log/xray
cd /var/log/xray
touch /var/log/xray/ws.log
touch /var/log/xray/split.log
touch /var/log/xray/upgrade.log
touch /var/log/xray/http.log
touch /var/log/xray/grpc.log
touch /etc/xray/.quota.logs

# Mengubah Permision Log File
chmod +x ws.log
chmod +x split.log
chmod +x upgrade.log
chmod +x http.log
chmod +x grpc.log
chmod +x /etc/xray/.quota.logs

# Menginstall Cron
apt install cron -y
#echo -e "0 0,6,12,18 * * * root backup
#0,15,30,45 * * * * root /usr/bin/xp
#*/5 * * * * root limit-ip-ssh
#*/5 * * * * root limit-ip-ws
#*/5 * * * * root limit-ip-split
#*/5 * * * * root limit-ip-http
#*/5 * * * * root limit-ip-grpc
#*/5 * * * * root auto-delete-ws
#*/5 * * * * root auto-delete-split
#*/5 * * * * root auto-delete-http
#*/5 * * * * root auto-delete-grpc
#*/5 * * * * root kill-ws
#*/5 * * * * root kill-http
#*/5 * * * * root kill-split
#*/5 * * * * root kill-grpc" >> /etc/crontab

echo -e "0 0,6,12,18 * * * root flock -n /tmp/backup.lock backup
0,15,30,45 * * * * root flock -n /tmp/xp.lock sleep 300 && /usr/bin/xp
*/5 * * * * root flock -n /tmp/limit-ip-ssh.lock limit-ip-ssh
*/5 * * * * root flock -n /tmp/limit-ip-ws.lock limit-ip-ws
*/5 * * * * root flock -n /tmp/limit-ip-split.lock limit-ip-split
*/5 * * * * root flock -n /tmp/limit-ip-http.lock limit-ip-http
*/5 * * * * root flock -n /tmp/limit-ip-grpc.lock limit-ip-grpc
*/5 * * * * root flock -n /tmp/auto-delete-ws.lock auto-delete-ws
*/5 * * * * root flock -n /tmp/auto-delete-split.lock auto-delete-split
*/5 * * * * root flock -n /tmp/auto-delete-http.lock auto-delete-http
*/5 * * * * root flock -n /tmp/auto-delete-grpc.lock auto-delete-grpc
*/5 * * * * root flock -n /tmp/kill-ws.lock kill-ws
*/5 * * * * root flock -n /tmp/kill-http.lock kill-http
*/5 * * * * root flock -n /tmp/kill-split.lock kill-split
*/5 * * * * root flock -n /tmp/kill-grpc.lock kill-grpc" >> /etc/crontab

# Menginstall Backup Database 2
cd
wget ${hosting}/installer/set-br.sh
chmod +x set-br.sh
./set-br.sh

# Membuat Service Limit Quota
cat> /etc/systemd/system/quota-ws.service << END
[Unit]
Description=Xray Quota Management Service By FN AutoSC
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/quota-ws
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
END

cat> /etc/systemd/system/quota-split.service << END
[Unit]
Description=Xray Quota Management Service By FN AutoSC
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/quota-split
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
END

cat> /etc/systemd/system/quota-http.service << END
[Unit]
Description=Xray Quota Management Service By FN AutoSC
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/quota-http
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
END

cat> /etc/systemd/system/quota-grpc.service << END
[Unit]
Description=Xray Quota Management Service By FN AutoSC
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/quota-grpc
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
END

# Menyalakan Service
systemctl daemon-reload
systemctl enable quota-ws
systemctl enable xray@upgrade
systemctl enable quota-http
systemctl enable xray@split
systemctl enable quota-split
systemctl enable xray@grpc
systemctl enable quota-grpc

# Melakukan Start Service
systemctl start quota-ws
systemctl start xray@upgrade
systemctl start quota-http
systemctl start xray@split
systemctl start quota-split
systemctl start xray@grpc
systemctl start quota-grpc

# Restart Sertvice
systemctl restart cron

cd

# Menghapus file tidak penting
rm -f /root/xray.sh
