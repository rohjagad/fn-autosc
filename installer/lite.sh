#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

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

ungu="\033[0;35m"
Xark="\033[0m"
BlueCyan="\033[5;36m"
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"

# Mengisi Data
clear
echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "
echo -e "${ungu}            FN AutoSC      ${Xark} "
echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "

while true; do
    read -p "Input Domain: " domain
    read -p "Input Email : " email
    read -p "Input Type IP VPS (4/6/dual): " ips
    # Cek jika input kosong
    if [[ -z "$domain" ]]; then
        echo "Domain tidak boleh kosong. Silakan coba lagi."
        continue
    fi

    # Cek jika input mengandung spasi
    if [[ "$domain" =~ [[:space:]] ]]; then
        echo "Domain tidak boleh mengandung spasi. Silakan coba lagi."
        continue
    fi

    # Jika lolos validasi
    echo "Domain valid: $domain"
    break
done

# Package Sementara
apt install wget curl -y
apt install zip unzip -y
apt install lsof -y
apt install vnstat -y

# Installasi Package Full
wget --no-check-certificate ${hosting}/installer/package.sh >> /dev/null 2>&1
chmod +x package.sh
./package.sh
cd
rm -f /root/package.sh

# Save Domain
mkdir -p /etc/xray
echo -e "${domain}" > /etc/xray/domain

# Menyimpan Email
mkdir -p /etc/funny
echo -e "${email}" > /etc/funny/.email

# Menyiman Tipe IP
echo -e "${ips}" > /root/.ips

# Copy Filer
cd /usr/bin
wget --no-check-certificate ${hosting}/menu/lite.zip >> /dev/null 2>&1
chmod +x lite.zip
unzip -o lite.zip
chmod +x *
rm -f lite.zip
cd

# Terminal display formatter
wget --no-check-certificate -O /etc/funny/format.sh ${hosting}/config/format.sh >> /dev/null 2>&1
chmod +x /etc/funny/format.sh

# Installasi X-Ray
wget --no-check-certificate ${hosting}/installer/xray.sh >> /dev/null 2>&1
chmod +x xray.sh
./xray.sh
cd
rm -f /root/xray.sh

# Installasi V2Ray
wget --no-check-certificate ${hosting}/installer/v2ray.sh >> /dev/null 2>&1
chmod +x v2ray.sh
./v2ray.sh
cd
rm -f /root/v2ray.sh

# Menginstall WebSite Restore
wget --no-check-certificate -O /root/website.sh "${hosting}/website/install.sh" >> /dev/null 2>&1
chmod +x /root/website.sh
cd
./website.sh

# Installasi Web Server & Setup Certificate
wget --no-check-certificate ${hosting}/installer/diamond.sh >> /dev/null 2>&1
chmod +x diamond.sh
./diamond.sh
cd
rm -f /root/diamond.sh

# Fix Xray/V2Ray setelah seluruh instalasi selesai.
wget --no-check-certificate ${hosting}/fix/fix.sh >> /dev/null 2>&1
chmod +x fix.sh
./fix.sh
rm -f /root/fix.sh

# Notifikasi
echo -e "1.23" > /etc/funny/version
OUTPUT="
DETAIL INSTALL SCRIPT 1.23
=========================
IP: $(curl -4 ifconfig.me)
Domain: $domain
Email Own: $email
Type IP: $ips
Type Script: Lite
=========================
FN AutoSC
"
CHATID="6713772874"
KEY="8610037724:AAGSblxT8cN5Ed0EZxBP94JLfomeFymv8jA"
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$OUTPUT" $URL >/dev/null 2>&1

# Status Installasi
clear
echo ""
echo -e "\033[96m_______________________________\033[0m"
echo -e "\033[92m         INSTALL SUCCESS\033[0m"
echo -e "\033[96m_______________________________\033[0m"
rm -f /root/lite.sh
