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

ips=$(cat /root/.ips)
clear

domain=$(cat /etc/xray/domain)

# Menginstall Package
apt install socat -y
apt install certbot -y
apt install lsof -y

# [ Menginstall Nginx ]
# Validasi dan set default untuk ips
if [[ -z $ips || ! $ips =~ ^(4|6|dual)$ ]]; then
    echo "Invalid or empty IP version. Defaulting to IPv4 configuration."
    ips="4"
fi

# Hosting
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"

# Install dan konfigurasi nginx
apt update && apt install nginx -y
systemctl stop nginx
rm -fr /etc/nginx/nginx.conf

# Unduh file konfigurasi berdasarkan nilai ips
case $ips in
    4)
        wget -O /etc/nginx/nginx.conf "${hosting}/config/4.conf"
        echo "IPv4 configuration applied."
        ;;
    6)
        wget -O /etc/nginx/nginx.conf "${hosting}/config/6.conf"
        echo "IPv6 configuration applied."
        ;;
    dual)
        wget -O /etc/nginx/nginx.conf "${hosting}/config/dual.conf"
        echo "Dual Stack configuration applied."
        ;;
esac

# Mengganti Domain Didalam Konfigurasi
sed -i "s|server_name tes1.rohshop.cloud;|server_name $domain;|" /etc/nginx/nginx.conf

# Menyimpan Informasi detail ISP
curl ipinfo.io/region | cut -d ' ' -f 2-10 > /root/.region
curl ipinfo.io/org | cut -d ' ' -f 2-10 > /root/.isp

# Mulai ulang nginx
systemctl start nginx

# Mematikan Port 80 / Disable HTTP PORT
portd=$(lsof -i:80 | awk '{print $1}')
[[ -n "$portd" ]] && pkill -f "${portd}" || true
systemctl stop nginx

issue_certificate() {
    local extra_flag="$1"
    local crt_path="$2"
    local key_path="$3"

    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade

    # 1. Try Let's Encrypt first
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d "$domain" --force --standalone -k ec-256 $extra_flag; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        # 2. Fallback to ZeroSSL
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d "$domain" --force --standalone -k ec-256 $extra_flag --server zerossl || true
    fi

    /root/.acme.sh/acme.sh --installcert -d "$domain" --force --fullchainpath "$crt_path" --keypath "$key_path" --ecc || true

    # 3. Emergency self-signed fallback so nginx/haproxy never fail to start
    if [[ ! -s "$crt_path" || ! -s "$key_path" ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$domain" -keyout "$key_path" -out "$crt_path" 2>/dev/null
    fi
}

# Pemilihan Opsi Generate Certificate
if [[ -z $ips || ! $ips =~ ^(4|6|dual)$ ]]; then
    echo "Invalid or empty IP version. Defaulting to IPv4."
    ips="4"
fi

if [[ $ips == "4" ]]; then
    systemctl stop nginx
    issue_certificate "" "/etc/xray/xray.crt" "/etc/xray/xray.key"
    chmod 644 /etc/xray/xray.*
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Cert installed for IPv4."
elif [[ $ips == "6" ]]; then
    systemctl stop nginx
    issue_certificate "--listen-v6" "/etc/xray/xray.crt" "/etc/xray/xray.key"
    chmod 644 /etc/xray/xray.*
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Cert installed for IPv6."
elif [[ $ips == "dual" ]]; then
    systemctl stop nginx
    issue_certificate "" "/etc/xray/xray4.crt" "/etc/xray/xray4.key"
    issue_certificate "--listen-v6" "/etc/xray/xray6.crt" "/etc/xray/xray6.key"
    cat /etc/xray/xray4.crt /etc/xray/xray6.crt > /etc/xray/xray.crt
    cat /etc/xray/xray4.key /etc/xray/xray6.key > /etc/xray/xray.key
    rm -f /etc/xray/xray4.crt /etc/xray/xray6.crt /etc/xray/xray4.key /etc/xray/xray6.key
    chmod 644 /etc/xray/xray.*
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Success Install Certificate Dual Stack"
fi
clear

# Menjalankan semua service
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx
systemctl restart apache2

# Menginstall Stunnel5
cd
wget ${hosting}/installer/stunnel5.sh
chmod +x stunnel5.sh
./stunnel5.sh

rm -f /root/diamond.sh
