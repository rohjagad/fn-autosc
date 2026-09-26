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

# Detail Hosting
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
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

# Every template ships publicly-known default credentials and the repository is
# public, while the account scripts only ADD clients - the shipped defaults stay
# active on every install. Replace all of them with per-install random values so
# no committed credential can be used against a fresh host.
#   ws.json      rerechan-store (vmess x3, trojan), cfbbaafc-... (vless, vmess)
#   grpc.json    cfbbaafc-...                        (vless, vmess, trojan)
#   split.json   019e0bf3-... , af7d5cf8-... , diy2020
#   upgrade.json nonescript-fn-project               (vmess, vless, trojan)
for def in "rerechan-store" \
           "cfbbaafc-8d52-450c-9fb0-145bc8221e6d" \
           "019e0bf3-dd56-11e9-aa37-5600024c1d6a" \
           "af7d5cf8-442d-4bb3-8a76-eb367178781d" \
           "diy2020" \
           "nonescript-fn-project"; do
    rep="$(xray uuid)"
    sed -i "s|${def}|${rep}|g" \
        /etc/xray/json/ws.json /etc/xray/json/upgrade.json \
        /etc/xray/json/split.json /etc/xray/json/grpc.json
done

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

# Bug 73: reinstall-safe cron install. The block below used to append
# unconditionally, so every reinstall stacked a second copy of all 17 daemon
# lines (every daemon ran twice per tick and locks scheduled double at-jobs).
# Drop previously installed panel lines first, then append exactly one set.
sed -i '/flock -n \/tmp\/\(backup\|xp\|expire-ssh\|limit-ip-ssh\|limit-ip-ws\|limit-ip-split\|limit-ip-http\|limit-ip-grpc\|auto-delete-ws\|auto-delete-split\|auto-delete-http\|auto-delete-grpc\|kill-ws\|kill-http\|kill-split\|kill-grpc\)\.lock /d' /etc/crontab
# Only schedule daemons this edition actually ships. The lite edition has no
# SSH tools, and a crontab entry for a command that is not installed fails on
# every tick ("flock: failed to execute expire-ssh: No such file or directory").
# Resolve each line's program and append the line only when it exists here.
cron_block="0 0,6,12,18 * * * root flock -n /tmp/backup.lock backup
0,15,30,45 * * * * root flock -n /tmp/xp.lock /usr/bin/xp
*/5 * * * * root flock -n /tmp/expire-ssh.lock expire-ssh
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
*/5 * * * * root flock -n /tmp/kill-grpc.lock kill-grpc"
while IFS= read -r cron_line; do
    [ -z "$cron_line" ] && continue
    cron_prog="${cron_line##* }"
    if command -v "$cron_prog" >/dev/null 2>&1 || [ -x "/usr/bin/${cron_prog##*/}" ]; then
        echo "$cron_line" >> /etc/crontab
    else
        echo "Skipping cron entry for ${cron_prog##*/}: not installed in this edition"
    fi
done <<< "$cron_block"

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
systemctl enable xray@ws
systemctl enable quota-ws
systemctl enable xray@upgrade
systemctl enable quota-http
systemctl enable xray@split
systemctl enable quota-split
systemctl enable xray@grpc
systemctl enable quota-grpc

# Melakukan Start Service
systemctl start xray@ws
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
