#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Auth sources race: same izin.txt on Pages + GitHub (synced), first valid reply wins; no primary/secondary.
    PERMISSION_CFPAGES="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_GITHUB="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
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
        # Fetch both auth sources at once; first complete valid reply wins (OR logic).
    PERMISSION_TMP=$(mktemp -d) || { echo "Failed to download permissions."; exit 1; }
    (curl -s --max-time 12 "$PERMISSION_CFPAGES" -o "$PERMISSION_TMP/a" 2>/dev/null; touch "$PERMISSION_TMP/a.done") &
    (curl -s --max-time 12 "$PERMISSION_GITHUB" -o "$PERMISSION_TMP/b" 2>/dev/null; touch "$PERMISSION_TMP/b.done") &
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
echo ""
echo ""
echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "
echo -e "${ungu}            FN AutoSC      ${Xark} "
echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "

while true; do
    read -p "Input Installer Domain: " installer_domain || exit 1
    read -p "Input Email : " email || exit 1
    read -p "Input Type IP VPS (4/6/dual): " ips || exit 1
    read -p "Your SlowDNS Nameserver: " nsdomain || exit 1
    # Cek jika input kosong
    if [[ -z "$installer_domain" ]]; then
        echo "Installer domain cannot be empty. Please try again."
        continue
    fi

    # Cek jika input mengandung spasi
    if [[ "$installer_domain" =~ [[:space:]] ]]; then
        echo "Installer domain cannot contain spaces. Please try again."
        continue
    fi

    # Cek format FQDN (sama seperti dm-menu/menu-dnstt/menu-argo)
    if ! [[ "$installer_domain" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Installer domain must be a valid DNS hostname. Please try again."
        continue
    fi

    # Jika lolos validasi
    echo "Installer domain valid: $installer_domain"
    break
done

# Menyimpan Installer Domain
mkdir -p /etc/xray
echo -e "${installer_domain}" > /etc/xray/installer-domain
# The installer domain starts as the first rotated entry, but remains an
# ordinary removable entry. Xray keeps working from the installer domain.
if [ ! -e /etc/xray/rotated-domains ]; then
    echo -e "${installer_domain}" > /etc/xray/rotated-domains
fi
curl -4 -sS --max-time 15 ipinfo.io/ip > /etc/.ip

# Menyimpan Email
mkdir -p /etc/funny
echo -e "${email}" > /etc/funny/.email

# Menyiman Tipe IP
echo -e "${ips}" > /root/.ips

# Menyimpan SlowDNS Nameserver
mkdir -p /etc/slowdns
echo -e "${nsdomain}" > /etc/slowdns/nsdomain

# Package Sementara
apt install wget curl -y
apt install zip unzip -y
apt install vnstat -y
apt install lsof -y

# Installasi Package Full
wget --no-check-certificate ${hosting}/installer/package.sh >> /dev/null 2>&1
chmod +x package.sh
./package.sh
cd
rm -f /root/package.sh

# Payload: individual files (scripts + binaries), staged and verified before
# replacing anything in /usr/bin. Found 513: no full.zip download/repack.
wget --no-check-certificate --timeout=600 --tries=3 -O /root/payload.sh "${hosting}/installer/payload.sh" >> /dev/null 2>&1 || {
    echo "Failed to download the payload helper." >&2
    exit 1
}
chmod +x /root/payload.sh
FN_HOSTING="$hosting" /root/payload.sh full || {
    echo "Payload installation failed; /usr/bin was not partially replaced." >&2
    exit 1
}
rm -f /root/payload.sh
cd /root

# Terminal display formatter
wget --no-check-certificate -O /etc/funny/format.sh ${hosting}/config/format.sh >> /dev/null 2>&1
chmod +x /etc/funny/format.sh

# Installasi SSH WebSocket
wget --no-check-certificate ${hosting}/installer/ssh.sh >> /dev/null 2>&1
chmod +x ssh.sh
./ssh.sh
cd
rm -f /root/ssh.sh

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

# Installasi OpenVPN
wget --no-check-certificate ${hosting}/installer/vpn.sh >> /dev/null 2>&1
chmod +x vpn.sh
./vpn.sh
cd
rm -f /root/vpn.sh

# Installasi SlowDNS
wget --no-check-certificate ${hosting}/installer/slowdns.sh >> /dev/null 2>&1
chmod +x slowdns.sh
./slowdns.sh
cd
rm -f /root/slowdns.sh

# Installasi L2TP
wget --no-check-certificate ${hosting}/installer/l2tp.sh >> /dev/null 2>&1
chmod +x l2tp.sh
./l2tp.sh
cd
rm -f /root/l2tp.sh

# Installasi Wireguard
wget --no-check-certificate ${hosting}/installer/wg.sh >> /dev/null 2>&1
chmod +x wg.sh
./wg.sh
cd
rm -f /root/wg.sh

# Installasi NoobzVPN'S
cd /root
wget --no-check-certificate ${hosting}/installer/noobz.sh >> /dev/null 2>&1
chmod +x noobz.sh
./noobz.sh
cd
rm -f /root/noobz.sh

# Installasi UDP Custom & UDP Request
wget --no-check-certificate ${hosting}/installer/udp.sh >> /dev/null 2>&1
chmod +x udp.sh
./udp.sh
rm -f /root/udp.sh
wget --no-check-certificate ${hosting}/installer/request.sh >> /dev/null 2>&1
chmod +x request.sh
./request.sh
rm -f /root/request.sh

# Restart
systemctl daemon-reload
systemctl restart fn-ohp
systemctl restart noobzvpns

# Fix Xray setelah seluruh instalasi selesai.
wget --no-check-certificate ${hosting}/fix/fix.sh >> /dev/null 2>&1
chmod +x fix.sh
./fix.sh
rm -f /root/fix.sh

# Installasi Selesai
echo -e "1.23" > /etc/funny/version
# Record the installed panel commit for the main-menu version display.
# Found 523: the old endpoint omitted /repos, returned 404, and made every
# fresh install show Unknown. Read the main branch SHA from the GitHub API,
# then fall back to git ls-remote when the API is rate-limited or unreachable.
record_install_commit() {
    local sha=""
    sha=$(curl -fsSL --max-time 15 \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/rohjagad/fn-autosc/commits/main" 2>/dev/null \
        | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' | head -1)
    if [ -z "$sha" ] && command -v git >/dev/null 2>&1; then
        sha=$(GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/rohjagad/fn-autosc.git refs/heads/main 2>/dev/null | awk 'NR==1 {print $1}')
    fi
    case "$sha" in
        *[!0-9a-f]*|"") sha="" ;;
    esac
    [ ${#sha} -eq 40 ] || sha="Unknown"
    mkdir -p /etc/funny
    printf '%s\n' "$sha" > /etc/funny/.install-commit
    chmod 600 /etc/funny/.install-commit 2>/dev/null || true
}
record_install_commit
OUTPUT="
DETAIL INSTALL SCRIPT 1.23
-------------------------
IP: $(curl -4 -s --max-time 15 ifconfig.me)
Installer Domain: $installer_domain
Email Own: $email
Type IP: $ips
Type Script: Full
SSH Port: 22, 3303
-------------------------
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
echo ""
echo -e "\033[96m-------------------------------\033[0m"
echo -e "\033[92m         INSTALL SUCCESS\033[0m"
echo -e "\033[96m-------------------------------\033[0m"
