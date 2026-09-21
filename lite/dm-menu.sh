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
        echo "Your IP is not in the database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"
    }

    output
clear

acme() {
clear
echo start
clear
domain=$(cat /etc/xray/domain)
clear
echo "
L FN 项目更新证书
=================================
Your Domain: $domain
=================================
4 For IPv4 &  For IPv6
"
echo -e "Generate new Ceritificate Please Input Type Your VPS"
read -p "Input Your Type Pointing ( 4 / 6 ): " ip_version
if [[ $ip_version == "4" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/1.23/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$domain" -keyout /etc/xray/xray.key -out /etc/xray/xray.crt 2>/dev/null
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray* /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
    echo "Cert installed for IPv4."
elif [[ $ip_version == "6" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/1.23/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$domain" -keyout /etc/xray/xray.key -out /etc/xray/xray.crt 2>/dev/null
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray* /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
    echo "Cert installed for IPv6."
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    cert
fi
}

cert2() {
email="faraskun02@gmail.com"
domain=$(cat /etc/xray/domain)

clear
echo "
L FN 项目更新证书
=================================
Your Domain: $domain
=================================
4 For IPv4 & 6 For IPv6
"
echo -e "Generate new Certificate. Please input your VPS type:"
read -p "Input Your Type Pointing (4 for IPv4 / 6 for IPv6): " ip_version

stop_services() {
    systemctl stop nginx
}

start_services() {
    systemctl start nginx
}

copy_certificates() {
    cat /etc/letsencrypt/live/$domain/fullchain.pem >> /etc/xray/xray.crt
    cat /etc/letsencrypt/live/$domain/privkey.pem >> /etc/xray/xray.key
    cd /etc/xray
    chmod 644 /etc/xray/xray* /etc/xray/*.pem
    cd
}

if [[ $ip_version == "4" || $ip_version == "6" ]]; then
    stop_services
    if [[ $ip_version == "4" ]]; then
        certbot certonly --standalone --preferred-challenges http -d $domain --non-interactive --agree-tos --email $email
    elif [[ $ip_version == "6" ]]; then
        certbot certonly --standalone --preferred-challenges http -d $domain --non-interactive --agree-tos --email $email --preferred-challenges http --standalone-supported-challenges http
    fi

    copy_certificates
    start_services
    echo "Cert installed for IPv$ip_version."
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    cert2
fi
}

dm() {
    clear
    CHATID=$(cat /etc/funny/.chatid)
    KEY=$(cat /etc/funny/.keybot)
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    TIME="10"
    DATE=$(date +"%Y-%m-%d")  # Hanya tanggal, bulan, dan tahun

    # Log Informasi Awal - Tampilkan domain yang sedang digunakan
    old_domain=$(cat /etc/xray/domain)
    log_message="<b>🚀 Log Perubahan Domain Xray</b>%0A"
    log_message+="<i>Informasi Perubahan:</i>%0A"
    log_message+="<pre>"
    log_message+="-------------------------------------%0A"
    log_message+="| Informasi            | Detail      |%0A"
    log_message+="-------------------------------------%0A"
    log_message+="| Tanggal              | $DATE       |%0A"
    log_message+="| Domain Lama          | $old_domain |%0A"
    log_message+="-------------------------------------%0A"
    log_message+="</pre>"
    log_message+="<b>Status:</b> Menampilkan Domain saat ini... 🔍"

    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$log_message&parse_mode=html" $URL >/dev/null

    echo -e "\e[33m===================================\033[0m"
    echo -e "Current Domain:"
    echo -e "$(cat /etc/xray/domain)"
    echo ""
    read -rp "New Domain/Host: " -e host
    echo ""

    if [ -z "$host" ]; then
        echo "No domain changes made."
        # Log jika tidak ada perubahan domain
        log_message="<b>🚨 Perubahan Domain Xray</b>%0A"
        log_message+="<i>Tidak ada perubahan domain yang dilakukan.</i>%0A"
        log_message+="<pre>"
        log_message+="-------------------------------------%0A"
        log_message+="| Tanggal              | $DATE       |%0A"
        log_message+="| Domain Lama          | $old_domain |%0A"
        log_message+="| Domain Baru          | Tidak ada   |%0A"
        log_message+="-------------------------------------%0A"
        log_message+="</pre>"
        log_message+="<b>Status:</b> Tidak ada perubahan dilakukan. ❌"

        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$log_message&parse_mode=html" $URL >/dev/null

        echo -e "\e[33m===================================\033[0m"
        read -n 1 -s -r -p "Press any key to return to menu"
        menu
    else
        # Simpan domain lama dan ganti dengan domain baru
        mv /etc/xray/domain /etc/xray/domain.old
        echo "$host" > /etc/xray/domain
        # Update konfigurasi di nginx.conf
        sed -i "s|server_name $old_domain;|server_name $host;|" /etc/nginx/nginx.conf
	sed -i 's/${old_domain}/${host}/g' /var/log/create/xray/ws/*
	sed -i 's/${old_domain}/${host}/g' /var/log/create/xray/http/*
	sed -i 's/${old_domain}/${host}/g' /var/log/create/xray/split/*
	sed -i 's/${old_domain}/${host}/g' /var/log/create/xray/split/*
	sed -i 's/${old_domain}/${host}/g' /var/log/create/ssh/*

        # Log perubahan domain
        log_message="<b>🚀 Perubahan Domain Xray</b>%0A"
        log_message+="<i>Berikut detail perubahan:</i>%0A"
        log_message+="<pre>"
        log_message+="-------------------------------------%0A"
        log_message+="| Informasi            | Detail      |%0A"
        log_message+="-------------------------------------%0A"
        log_message+="| Tanggal              | $DATE       |%0A"
        log_message+="| Domain Lama          | $old_domain |%0A"
        log_message+="| Domain Baru          | $host       |%0A"
        log_message+="-------------------------------------%0A"
        log_message+="</pre>"
        log_message+="<b>Status:</b> Domain berhasil diperbarui ✅"

        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$log_message&parse_mode=html" $URL >/dev/null

        # Konfirmasi untuk memperbarui sertifikat
        read -rp "Renew SSL certificate? (y/n): " cert_choice
        if [[ "$cert_choice" == "y" || "$cert_choice" == "Y" ]]; then
            echo -e "\nRenewing SSL certificate..."
            cert_status="Berhasil"
            cert
        else
            cert_status="Tidak diperbarui"
        fi

        # Log untuk pembaruan sertifikat
        log_message="<b>🔧 Pembaruan Sertifikat</b>%0A"
        log_message+="<i>Hasil pembaruan sertifikat:</i>%0A"
        log_message+="<pre>"
        log_message+="-------------------------------------%0A"
        log_message+="| Tanggal              | $DATE       |%0A"
        log_message+="| Pembaruan Sertifikat | $cert_status|%0A"
        log_message+="-------------------------------------%0A"
        log_message+="</pre>"
        log_message+="<b>Status:</b> Sertifikat diperbarui: $cert_status"

        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$log_message&parse_mode=html" $URL >/dev/null

        echo -e "\e[33m===================================\033[0m"
        echo "Notification sent to Telegram."
        echo -e "\e[33m===================================\033[0m"
        read -n 1 -s -r -p "Press any key to return to menu"
        menu
    fi
}

fn() {
clear
echo start
domain=$(cat /etc/xray/domain)
systemctl stop nginx
cd /root/
clear
echo "Starting... Port 80 will be stopped during SSL certificate installation"
certbot certonly --standalone --preferred-challenges http --agree-tos --email melon334456@gmail.com -d $domain 
cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
cd /etc/xray
chmod 644 /etc/xray/xray.key
chmod 644 /etc/xray/xray.crt
systemctl start nginx
}

cert() {
clear
echo -e "
========================
[ Generate Certificate ]
========================

1. Issue via acme.sh
2. Issue via Certbot
========================
"
read -p "Input option: " akz
case $akz in
1) acme ;;
2) cert2 ;;
*) cert ;;
esac
}

dmsl() {
systemctl stop nginx
clear
#detail nama perusahaan
country="ID"
state="Central Kalimantan"
locality="Kab. Kota Waringin Timur"
organization="FN AutoSC"
organizationalunit="99999"
commonname="FN"
email="rerechan0202@gmail.com"

# delete
rm -fr /etc/xray/xray.*
rm -fr /etc/xray/funny.pem

# make a certificate
openssl genrsa -out /etc/xray/xray.key 2048
openssl req -new -x509 -key /etc/xray/xray.key -out /etc/xray/xray.crt -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
chmod 644 /etc/xray/*
systemctl daemon-reload
service nginx restart
echo -e "Self-signed certificate generated successfully"
}

dm1() {
clear
echo -e "
=================================
[          Domain Menu          ]
=================================

1. Change Server Domain
2. Renew Certificate (Acme: IPv4/IPv6)
3. Renew Certificate (Certbot: IPv4 Only)
4. Generate Self-Signed Certificate
=================================
      Press [Ctrl + C] to exit
"
read -p "Input option: " apw
case $apw in
1) clear ; dm ;;
2) clear ; cert ;;
3) clear ; fn ;;
4) clear ; dmsl ;;
*) dm1 ;;
esac
}

dm1
