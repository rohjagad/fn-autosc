#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

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
        REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE") || { echo "Permission data invalid."; exit 1; }
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


clear
echo ""
echo ""
# Fungsi untuk membaca file
read_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cat "$file_path" | tr -d '\n'
    else
        echo ""
    fi
}

# Fungsi untuk mengirim notifikasi Telegram
send_telegram_notification() {
    local chat_id="$1"
    local key="$2"
    local message="$3"
    [ -z "$chat_id" ] || [ -z "$key" ] && return 0
    local api_url="https://api.telegram.org/bot${key}/sendMessage"
    local TIME="${TIME:-10}"

    curl -s --max-time $TIME --data-urlencode "chat_id=$chat_id" --data-urlencode "disable_web_page_preview=1" --data-urlencode "parse_mode=html" --data-urlencode "text=$(printf '%s' "$message" | sed -e 's/&/\&amp;/g' -e 's|^\([A-Za-z][^:]*: \)\(.*\)$|<code>\1\2</code>|')" $api_url >/dev/null 2>&1
}

# Fungsi untuk membuat pengguna SSH
create_ssh_user() {
    local username="$1"
    local password="$2"

    # Tambahkan pengguna tanpa home directory dan shell /bin/false
    useradd -s /bin/false -M "$username"
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal membuat pengguna $username."
        return 1
    fi

    # Setel password pengguna
    echo -e "${password}\n${password}" | passwd "$username" > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal mengatur password untuk $username."
        return 1
    fi

    # The card advertises "Limit IP: 1"; without this file limit-ip-ssh falls back to
    # the account to a limit of 2, so the printed limit would never match what is
    # enforced (addssh does write it).
    mkdir -p /etc/xray/limit/ip/ssh
    echo 1 > "/etc/xray/limit/ip/ssh/${username}"

    return 0
}

# Fungsi untuk menjadwalkan penghapusan pengguna
schedule_user_expiration() {
    local username="$1"
    local minutes="$2"

    # Buat perintah untuk memutus koneksi dan menghapus pengguna
    local disconnect_cmd="pkill -u $username"
    local delete_cmd="userdel -f $username; rm -f /var/log/create/ssh/${username}.log /etc/xray/limit/ip/ssh/${username}"

    # Jadwalkan dengan `at`
    echo "${disconnect_cmd}; ${delete_cmd}" | at now + "$minutes" minutes > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal menjadwalkan penghapusan pengguna $username."
        return 1
    fi

    return 0
}

# Baca konfigurasi
# Rotated domains are independent; the installer domain may be deleted from this list.
rotated_domains=()
if [ -s /etc/xray/rotated-domains ]; then
    _seen="|"
    while IFS= read -r _d || [ -n "$_d" ]; do
        _d=$(echo "$_d" | tr -d '[:space:]')
        if [ -n "$_d" ] && [[ "$_seen" != *"|$_d|"* ]]; then
            rotated_domains+=("$_d")
            _seen="$_seen$_d|"
        fi
    done < /etc/xray/rotated-domains
fi
if [ ${#rotated_domains[@]} -eq 0 ]; then
    echo ""
    echo -e "\033[0;31mRotated domain is empty. Please add a rotated domain from Domain Menu first.\033[0m"
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
    exit 1
fi
rotated_domain_seq=$(cat /etc/xray/.rotated-domainseq 2>/dev/null || echo 0)
rotated_domain="${rotated_domains[$((rotated_domain_seq % ${#rotated_domains[@]}))]}"
echo $((rotated_domain_seq+1)) > /etc/xray/.rotated-domainseq
pub_key=$(read_file "/etc/slowdns/server.pub")
nameserver=$(read_file "/etc/slowdns/nsdomain")
chat_id=$(read_file "/etc/funny/.chatid")
key=$(read_file "/etc/funny/.keybot")
isp=$(cat /root/.isp 2>/dev/null)
region=$(cat /root/.region 2>/dev/null)

echo -e "[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-\033[0m"
echo -e "\033[1;33m Create SSH Account \033[0m"
echo -e "[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-\033[0m"
echo ""
echo -e "\033[38;5;208m0 not allowed\033[0m"
read -p "Expired (minutes): " masaaktif
while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
    echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
    read -p "Expired (minutes): " masaaktif || exit 1
done

clear
echo ""
echo ""
# Buat username dan password otomatis
# Retry up to 10 times to avoid collision with active trial accounts
for _i in $(seq 1 10); do
    username="trial$(shuf -i 100-999 -n 1)"
    id "$username" &>/dev/null || break
    username=""
done
if [ -z "$username" ]; then
    echo "Failed to generate unique trial username after 10 attempts."
    exit 1
fi
password="1"

# Buat pengguna SSH
create_ssh_user "$username" "$password"
if [[ $? -ne 0 ]]; then
    exit 1
fi

# Jadwalkan penghapusan pengguna
schedule_user_expiration "$username" "$masaaktif"
if [[ $? -ne 0 ]]; then
    exit 1
fi

# Buat pesan notifikasi
message=$(cat <<EOF
-------------------
🟢 SSH ACCOUNT 🟢
-------------------
Rotated Domain   : $rotated_domain
ISP        : $isp
Region     : $region
Username   : $username
Password   : $password
Expired    : $masaaktif Minutes
Limit IP   : 1
-------------------
DNS        : 1.1.1.1 / 8.8.8.8
Pub Key    : $pub_key
Nameserver : $nameserver
-------------------
OpenSSH       : 22, 3303
Dropbear      : 111, 109
NonTLS        : 80, 8880, 2052, 2082, 2086, 2095
Enhanced      : 2080
HTTP Proxy    : 3128 ( Limit IP to Server )
OHP           : 9088
WS TLS        : 443, 2053, 2083, 2087, 2096
STUNNEL5      : 777
Slowdns       : 53
Udp Custom    : 1-65535
Udp Request   : 1-65535
BadVpn/Udpgw  : 7300
-------------------
OVPN WS       : 2086
OVPN TCP/UDP  : 1194 / 2200
Config OVPN   : http://${rotated_domain}/web/openvpn.zip
-------------------
EOF
)

# Kirim notifikasi ke Telegram
send_telegram_notification "$chat_id" "$key" "$(printf '%s' "$message" | sed -e '/^Domain     : /d' -e 's/&/\&amp;/g' -e 's|^\([A-Za-z][^:]*: \)\(.*\)$|<code>\1\2</code>|')"

mkdir -p /var/log/create/ssh
echo "$message" > /var/log/create/ssh/${username}.log

clear
echo ""
echo ""
source /etc/funny/format.sh
format_display "$message"
