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

menu-argo() {
# Fix Nameserver
[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || {
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

setup() {
# Clear Screen
clear

# Copy File Core
wget https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm -fr cloudflared-linux-amd64.deb

# Membuat Konfigurasi
rm -fr /etc/cloudflared/*
mkdir -p /etc/cloudflared

clear
echo -e "Log in to your Cloudflare account"
cloudflared tunnel login

clear
random=$(openssl rand -base64 15 | tr -dc 'a-z' | head -c 8)
echo " Creating Argo Tunnel Node "
echo "$random" > /root/.rcs
rcs=$(cat /root/.rcs)
cloudflared tunnel create $rcs
clear
id=$(basename ~/.cloudflared/*.json | sed 's/\.json$//')
echo -e "Save Your Tunnel ID"
echo -e "ID: $id"
sleep 10
clear
echo -e "
Set Up Argo Tunnel Domain
=========================

Example: mysubdom.myvpn.com

Replace mysubdom with your subdomain and myvpn.com with your Cloudflare domain.
=========================
"
read -p "New Domain: " opws
cloudflared tunnel route dns $rcs $opws
echo "$opws" > /etc/xray/domargo
domargo="$opws"
clear
cat > /etc/cloudflared/config.yml << END
tunnel: $rcs
credentials-file: /root/.cloudflared/$id.json

ingress:
  - hostname: $domargo
    service: http://localhost:80
  - hostname: $domargo
    service: http://localhost:2080
    originRequest:
      httpHostHeader: $domargo
      headers:
        Upgrade: websocket
        Connection: Upgrade
  - service: http_status:404
END
# Menyimpan Domain
#echo "$domargo" > /etc/xray/domargo

# Menjalankan Servixe
sudo cloudflared service uninstall
sudo cloudflared service install
}

detail() {
clear
edussh_service=$(systemctl status cloudflared | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
ssws="\e[1;32m[ ON ]\033[0m"
else
ssws="\e[1;31m[ OFF ]\033[0m"
fi
domargo=$(cat /etc/xray/domargo)
doms=$(cat /etc/xray/domssh)
clear
echo -e "
    Argo Tunnel Details
═════════════════════════════════

Port HTTP:
- 80 ( Standard )
- 8080
- 8880
- 2052
- 2082
- 2086
- 2095

Port HTTPS:
- 443 ( Standard )
- 8443
- 2053
- 2083
- 2087
- 2096

# Detail
- Status       : $ssws
- Domain Nginx : $domargo
- Domain SSH WS: $domargo
═════════════════════════════════
Currently supported protocols:
-> SSH WebSockets
-> All Connections via Nginx
-> Xray / V2Ray / Sing-box
"
}
tamp() {
edussh_service=$(systemctl status cloudflared | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
ssws="\e[1;32m[ ON ]\033[0m"
else
ssws="\e[1;31m[ OFF ]\033[0m"
fi
clear
echo -e "
==========================
     Argo Tunnel Menu
==========================
Status: $ssws

1. Install Argo Tunnel
2. Restart Argo Tunnel
3. Argo Tunnel Details
0. Back to Main Menu
══════════════════════════
   Press [Ctrl + C] to exit
"
read -p "Input option: " opws
case $opws in
1) setup ;;
2) clear ; reres ;;
3) clear ; detail ;;
0) clear ; menu ;;
*) clear ; tamp ;;
esac
}

tamp
}

menu-argo