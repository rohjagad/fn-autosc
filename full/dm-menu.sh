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
        local expired_date
        expired_date=$(date -d "$1" +%s 2>/dev/null)
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
        echo "Your IP is not in the database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    # A "lifetime" entry means auth is off: the expiry check is skipped
    # (is-decision.md 28). This gate also runs during installation, so a
    # lifetime machine installs without a date.
    if [ "$EXPIRED_DATE" = "lifetime" ]; then
        REMAINING_DAYS="lifetime"
    else
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    fi
    if [ "$REMAINING_DAYS" != "lifetime" ] && [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"; fi
    }

clear

red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
NC='\033[0m'

rainbow_sep() {
  local text="${1:-===================================}"
  local output=''
  local i segment fraction r g b color
  local -a red=(255 255 0 0 0 255 255)
  local -a green=(0 255 255 255 0 0 0)
  local -a blue=(0 0 0 255 255 255 0)
  for ((i = 0; i < ${#text}; i++)); do
    if ((i == ${#text} - 1)); then
      segment=5
      fraction=$((${#text} - 1))
    else
      segment=$((i * 6 / (${#text} - 1)))
      fraction=$((i * 6 % (${#text} - 1)))
    fi
    r=$((red[segment] + (red[segment + 1] - red[segment]) * fraction / (${#text} - 1)))
    g=$((green[segment] + (green[segment + 1] - green[segment]) * fraction / (${#text} - 1)))
    b=$((blue[segment] + (blue[segment + 1] - blue[segment]) * fraction / (${#text} - 1)))
    printf -v color '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
    output+="${color}${text:i:1}"
  done
  printf '%b\n' "${output}${NC}"
}

separator=$(rainbow_sep '===================================')
blue_sep="${blue}-----------------------------------${NC}"

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
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
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
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Cert installed for IPv4."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
elif [[ $ip_version == "6" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
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
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Cert installed for IPv6."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    cert
fi
}

cert2() {
email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")
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
    # `cat src > dst` creates/truncates dst before src is read, so when certbot
    # failed (rate limit, HTTP-01 failure) and never produced the files the live
    # certificate was left as a 0-byte file and nginx could not start. Refuse to
    # touch it unless certbot actually produced a non-empty pair.
    if [[ ! -s /etc/letsencrypt/live/$domain/fullchain.pem || ! -s /etc/letsencrypt/live/$domain/privkey.pem ]]; then
        echo "certbot did not produce certificate files for $domain - keeping the existing certificate."
        return 1
    fi
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
}

if [[ $ip_version == "4" || $ip_version == "6" ]]; then
    stop_services
    if [[ $ip_version == "4" ]]; then
        certbot certonly --standalone --preferred-challenges http -d $domain --non-interactive --agree-tos --email $email
    elif [[ $ip_version == "6" ]]; then
        certbot certonly --standalone --preferred-challenges http -d $domain --non-interactive --agree-tos --email $email --preferred-challenges http --standalone-supported-challenges http
    fi

    if copy_certificates; then
        echo "Cert installed for IPv$ip_version."
    else
        echo "Certificate renewal failed - the previously installed certificate was kept."
    fi
    start_services
    systemctl restart noobzvpns 2>/dev/null || true
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    cert2
fi
}

dm() {
    clear
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
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

    if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$log_message" $URL >/dev/null
    fi

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

        if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$log_message" $URL >/dev/null
    fi

        echo -e "\e[33m===================================\033[0m"
        read -n 1 -s -r -p "Press any key to return..." || true
        return 0
    elif ! [[ "$host" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Domain must be a valid DNS hostname."
        read -n 1 -s -r -p "Press any key to return..." || true
        return 0
    else
        # Simpan domain lama dan ganti dengan domain baru
        mv /etc/xray/domain /etc/xray/domain.old
        echo "$host" > /etc/xray/domain
        # Update konfigurasi di nginx.conf
        sed -i "s|server_name $old_domain;|server_name $host;|" /etc/nginx/nginx.conf
	sed -i "s|${old_domain}|${host}|g" /var/log/create/xray/ws/* 2>/dev/null || true
	sed -i "s|${old_domain}|${host}|g" /var/log/create/xray/http/* 2>/dev/null || true
	sed -i "s|${old_domain}|${host}|g" /var/log/create/xray/split/* 2>/dev/null || true
	sed -i "s|${old_domain}|${host}|g" /var/log/create/xray/grpc/* 2>/dev/null || true
	sed -i "s|${old_domain}|${host}|g" /var/log/create/ssh/* 2>/dev/null || true

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

        if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$log_message" $URL >/dev/null
    fi

        # Konfirmasi untuk memperbarui sertifikat
        read -rp "Renew SSL certificate? (y/n): " cert_choice
        if [[ "$cert_choice" == "y" || "$cert_choice" == "Y" ]]; then
            echo -e "\nRenewing SSL certificate..."
            cert_status="Berhasil"
            cert
        else
            cert_status="Tidak diperbarui"
            systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
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

        if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$log_message" $URL >/dev/null
    fi

        if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
            echo -e "\e[33m===================================\033[0m"
            echo "Notification sent to Telegram."
            echo -e "\e[33m===================================\033[0m"
        fi
        read -n 1 -s -r -p "Press any key to return..." || true
        return 0
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
certbot certonly --standalone --preferred-challenges http --agree-tos --email "$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")" -d $domain 
if [[ -s /etc/letsencrypt/live/$domain/fullchain.pem && -s /etc/letsencrypt/live/$domain/privkey.pem ]]; then
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
else
    echo "certbot failed - keeping the existing certificate."
fi
cd /etc/xray
systemctl start nginx
systemctl restart noobzvpns 2>/dev/null || true
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

cert() {
clear
echo -e "${NC}${separator}
        GENERATE CERTIFICATE
${separator}
${green}1${NC}. Issue via acme.sh
${green}2${NC}. Issue via Certbot
${green}0${NC}. Back to Domain Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " akz || exit 0
case $akz in
1) clear ; acme ;;
2) clear ; cert2 ;;
0|00) clear ; return 0 ;;
*) clear ; cert ;;
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
email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")

# delete
rm -fr /etc/xray/xray.*
rm -f /etc/haproxy/funny.pem

# make a certificate
openssl genrsa -out /etc/xray/xray.key 2048
openssl req -new -x509 -key /etc/xray/xray.key -out /etc/xray/xray.crt -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null
systemctl daemon-reload
systemctl restart haproxy 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
service nginx restart
echo -e "Self-signed certificate generated successfully"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

dm1() {
clear
echo -e "${NC}${separator}
            DOMAIN MENU
${separator}
${green}1${NC}. Change Server Domain
${green}2${NC}. Renew Certificate (Acme: IPv4/IPv6)
${green}3${NC}. Renew Certificate (Certbot: IPv4 Only)
${green}4${NC}. Generate Self-Signed Certificate
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " apw || exit 0
case $apw in
1) clear ; dm ; dm1 ;;
2) clear ; cert ; dm1 ;;
3) clear ; fn ; dm1 ;;
4) clear ; dmsl ; dm1 ;;
0|00) clear ; menu ;;
*) clear ; dm1 ;;
esac
}

dm1
