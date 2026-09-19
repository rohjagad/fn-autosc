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

clear

menu-argo() {

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

# Fix Nameserver
[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || {
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

setup() {
# Clear Screen
clear

# Copy File Core
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm -fr cloudflared-linux-amd64.deb

# Membuat Konfigurasi
rm -fr /etc/cloudflared/*
mkdir -p /etc/cloudflared

clear
echo -e "Login to your cloudflare Account"
cloudflared tunnel login

clear
random=$(openssl rand -base64 15 | tr -dc 'a-z' | head -c 8)
echo " Create Node For Server Data "
echo "$random" > /root/.rcs
rcs=$(cat /root/.rcs)
cloudflared tunnel create $rcs
clear
id=$(basename ~/.cloudflared/*.json | sed 's/\.json$//')
echo -e "Save Your ID"
echo -e "ID: $id"
sleep 10
clear
echo -e "
Setup Your Domain Argo Tunnel
=============================

Example: mysubdom.myvpn.com

replace mysubdomain with your desired subdomain and replace myvpn.com with the domain you chose in cloudflare for argo tunnel after login
=============================
"
read -p "Input New Domain: " opws
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
<= Detail Service Argo Tunnel =>
════════════════════════════════

Port HTTP:
- 80 ( Standar )
- 8080
- 8880
- 2052
- 2082
- 2086
- 2095

Port HTTPS:
- 443 ( Standar )
- 8443
- 2053
- 2083
- 2087
- 2096

#Detail
- Status       : $ssws
- Domain Nginx : $domargo
- Domain SSH WS: $domargo
════════════════════════════════
Currently only supports connections on
-> SSH WebSockets
-> All Connection With Nginx
-> X-Ray/V2ray/V2rayfly/SibgBox Server
"
}
tamp() {
edussh_service=$(systemctl status cloudflared 2>/dev/null | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $edussh_service == "running" ]]; then
    ssws="${green}ON${NC}"
else
    ssws="${red}OFF${NC}"
fi
clear
echo -e "${NC}${separator}
             MENU ARGO
${separator}
Status       : $ssws
${blue_sep}
${green}1${NC}. Install Argo
${green}2${NC}. Restart Argo Tunnel
${green}3${NC}. Detail Service Argo
${green}0${NC}. Back To Menu Default
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " opws
case $opws in
1) clear ; setup ;;
2) clear ; reres ;;
3) clear ; detail ;;
0) clear ; menu ;;
*) clear ; tamp ;;
esac
}

tamp
}

menu-argo