#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

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
    read -p "Input Domain: " domain || exit 1
    read -p "Input Email : " email || exit 1
    read -p "Input Type IP VPS (4/6/dual): " ips || exit 1
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

    # Cek format FQDN (sama seperti dm-menu/menu-dnstt/menu-argo)
    if ! [[ "$domain" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Domain harus berupa hostname DNS yang valid. Silakan coba lagi."
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

# Lite ships no SSH tooling, so installer/ssh.sh never runs - and that is the
# script that moves dropbear off its default port 22. sshd already owns 22, so
# dropbear failed on every lite install ("Failed listening on '22': Address
# already in use", then systemd gave up). Disable the unused service.
systemctl disable --now dropbear >/dev/null 2>&1 || true
# stunnel5/haproxy (port 777) is configured to forward to dropbear:109, which lite
# neither moves nor uses, so the frontend would be dead. Turn it off with it.
systemctl disable --now haproxy >/dev/null 2>&1 || true
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

# HAProxy was started by diamond.sh -> stunnel5.sh on port 777 forwarding to
# dropbear:109. Lite does not run dropbear, so the frontend has no backend;
# disable it as intended by Fix 166.
systemctl disable --now haproxy >/dev/null 2>&1 || true

# Fix Xray setelah seluruh instalasi selesai.
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
SSH Port: 22, 3303
=========================
FN AutoSC
"
# Install notification uses the operator's own bot credentials, set later via
# menu-bot (/etc/funny/.keybot and /etc/funny/.chatid). No credential is
# committed to the repository and nothing is sent anywhere by default.
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    curl -4 -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$OUTPUT" $URL >/dev/null 2>&1
fi

# Status Installasi
clear
echo ""
echo -e "\033[96m_______________________________\033[0m"
echo -e "\033[92m         INSTALL SUCCESS\033[0m"
echo -e "\033[96m_______________________________\033[0m"
rm -f /root/lite.sh
