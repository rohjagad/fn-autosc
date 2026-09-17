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
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/1.23"

# Install dan konfigurasi nginx
apt update && apt install nginx -y
syste   mctl stop nginx
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
pkill ${portd}
systemctl stop nginx

# Pemilihan Opsi Generate Certificate
if [[ -z $ips || ! $ips =~ ^(4|6|dual)$ ]]; then
    echo "Invalid or empty IP version. Defaulting to IPv4."
    ips="4"
fi

if [[ $ips == "4" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
    chmod 644 /etc/xray/xray.*
    systemctl start nginx
    echo "Cert installed for IPv4."
elif [[ $ips == "6" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6
    ~/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
    chmod 644 /etc/xray/xray.*
    systemctl start nginx
    echo "Cert installed for IPv6."
elif [[ $ips == "dual" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray4.crt --keypath /etc/xray/xray4.key --ecc
    /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6
    ~/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray6.crt --keypath /etc/xray/xray6.key --ecc
    cat /etc/xray/xray4.crt /etc/xray/xray6.crt > /etc/xray/xray.crt
    cat /etc/xray/xray4.key /etc/xray/xray6.key > /etc/xray/xray.key
    rm -f /etc/xray/xray4.crt /etc/xray/xray6.crt /etc/xray/xray4.key /etc/xray/xray6.key
    chmod 644 /etc/xray/xray.*
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
