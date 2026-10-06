#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Konfigurasi URL izin
    PERMISSION_PRIMARY="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_FALLBACK="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s --max-time 15 ifconfig.me) # Mendapatkan IP lokal

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
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
        # Fetch both auth sources at once; first complete valid reply wins (OR logic).
    PERMISSION_TMP=$(mktemp -d) || { echo "Failed to download permissions."; exit 1; }
    (curl -s --max-time 12 "$PERMISSION_PRIMARY" -o "$PERMISSION_TMP/a" 2>/dev/null; touch "$PERMISSION_TMP/a.done") &
    (curl -s --max-time 12 "$PERMISSION_FALLBACK" -o "$PERMISSION_TMP/b" 2>/dev/null; touch "$PERMISSION_TMP/b.done") &
    PERMISSION_DATA=""; end=$((SECONDS+15))
    while [ $SECONDS -lt $end ]; do
        for f in "$PERMISSION_TMP/a" "$PERMISSION_TMP/b"; do
            if [ -f "$f.done" ] && grep -q "###" "$f" 2>/dev/null; then PERMISSION_DATA=$(cat "$f"); break 2; fi
        done
        jobs -rp | grep -q . || break
        sleep 1
    done
    kill $(jobs -rp) 2>/dev/null
    wait 2>/dev/null
    rm -rf "$PERMISSION_TMP"
    [ -z "$PERMISSION_DATA" ] && { echo "Failed to download permissions."; exit 1; }

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep -wF "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP doesn’t have on database"
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
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"; fi
    }

    output

ips=$(cat /root/.ips)
clear
echo ""
echo ""
echo ""
echo ""
echo ""
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
curl -m 10 ipinfo.io/region | cut -d ' ' -f 2-10 > /root/.region
curl -m 10 ipinfo.io/org | cut -d ' ' -f 2-10 > /root/.isp

# Mulai ulang nginx
systemctl start nginx

# Mematikan Port 80 / Disable HTTP PORT
fuser -k 80/tcp 2>/dev/null || true
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
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 600 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Cert installed for IPv4."
elif [[ $ips == "6" ]]; then
    systemctl stop nginx
    issue_certificate "--listen-v6" "/etc/xray/xray.crt" "/etc/xray/xray.key"
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 600 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Cert installed for IPv6."
elif [[ $ips == "dual" ]]; then
    systemctl stop nginx
    issue_certificate "" "/etc/xray/xray4.crt" "/etc/xray/xray4.key"
    issue_certificate "--listen-v6" "/etc/xray/xray6.crt" "/etc/xray/xray6.key"
    cat /etc/xray/xray4.crt /etc/xray/xray6.crt > /etc/xray/xray.crt
    cat /etc/xray/xray4.key /etc/xray/xray6.key > /etc/xray/xray.key
    rm -f /etc/xray/xray4.crt /etc/xray/xray6.crt /etc/xray/xray4.key /etc/xray/xray6.key
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 600 /etc/haproxy/funny.pem
    systemctl start nginx
    echo "Success Install Certificate Dual Stack"
fi
clear
echo ""
echo ""
echo ""
echo ""
echo ""
# Menjalankan semua service
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx
systemctl restart apache2 2>/dev/null || true

# Menginstall Stunnel5
cd
wget ${hosting}/installer/stunnel5.sh
chmod +x stunnel5.sh
./stunnel5.sh

rm -f /root/diamond.sh
