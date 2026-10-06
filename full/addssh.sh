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
clear
echo ""
echo ""
echo ""
clear_screen() {
    clear
    echo ""
    echo ""
    echo ""
}

read_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cat "$file_path" | xargs
    else
        echo ""
    fi
}

calculate_expiration_date() {
    local days="$1"
    date -d "+$days days" +"%Y-%m-%d"
}

send_telegram_notification() {
    local chat_id="$1"
    local key="$2"
    local message="$3"
    [ -z "$chat_id" ] || [ -z "$key" ] && return 0
    local api_url="https://api.telegram.org/bot${key}/sendMessage"
    local TIME="${TIME:-10}"

    curl -s --max-time $TIME --data-urlencode "chat_id=$chat_id" --data-urlencode "text=$message" $api_url >/dev/null 2>&1
}

create_ssh_user() {
    local username="$1"
    local password="$2"
    local expiration_date="$3"

    useradd -e "$expiration_date" -s /bin/false -M "$username" || {
        echo -e "\033[0;31mFailed to create user '$username'.\033[0m"
        return 1
    }
    echo "$username:$password" | chpasswd
}

main() {
    clear_screen

    local domain=$(read_file "/etc/xray/domain")
# Alternate domain, rotated for balance (no default; list order only)
rdomains=("$domain")
if [ -s /etc/xray/domains ]; then
    _seen="|$domain|"
    while IFS= read -r _d || [ -n "$_d" ]; do
        _d=$(echo "$_d" | tr -d '[:space:]')
        if [ -n "$_d" ] && [[ "$_seen" != *"|$_d|"* ]]; then
            rdomains+=("$_d")
            _seen="$_seen$_d|"
        fi
    done < /etc/xray/domains
fi
dseq=$(cat /etc/xray/.domainseq 2>/dev/null || echo 0)
rdomain="${rdomains[$((dseq % ${#rdomains[@]}))]}"
echo $((dseq+1)) > /etc/xray/.domainseq
alldom=$(printf '%s,' "${rdomains[@]}" | sed 's/,$//; s/,/, /g')
    local pub_key=$(read_file "/etc/slowdns/server.pub")
    local nameserver=$(read_file "/etc/slowdns/nsdomain")
    local chat_id=$(read_file "/etc/funny/.chatid")
    local key=$(read_file "/etc/funny/.keybot")

    echo -e "\033[38;2;255;0;0m-\033[38;2;255;80;0m-\033[38;2;255;161;0m-\033[38;2;255;241;0m-\033[38;2;188;255;0m-\033[38;2;108;255;0m-\033[38;2;27;255;0m-\033[38;2;0;255;53m-\033[38;2;0;255;134m-\033[38;2;0;255;214m-\033[38;2;0;215;255m-\033[38;2;0;135;255m-\033[38;2;0;54;255m-\033[38;2;26;0;255m-\033[38;2;107;0;255m-\033[38;2;187;0;255m-\033[38;2;255;0;242m-\033[38;2;255;0;162m-\033[38;2;255;0;81m-\033[38;2;255;0;0m-\033[0m"
    echo -e "\033[1;33m Create SSH Account \033[0m"
    echo -e "\033[38;2;255;0;0m-\033[38;2;255;80;0m-\033[38;2;255;161;0m-\033[38;2;255;241;0m-\033[38;2;188;255;0m-\033[38;2;108;255;0m-\033[38;2;27;255;0m-\033[38;2;0;255;53m-\033[38;2;0;255;134m-\033[38;2;0;255;214m-\033[38;2;0;215;255m-\033[38;2;0;135;255m-\033[38;2;0;54;255m-\033[38;2;26;0;255m-\033[38;2;107;0;255m-\033[38;2;187;0;255m-\033[38;2;255;0;242m-\033[38;2;255;0;162m-\033[38;2;255;0;81m-\033[38;2;255;0;0m-\033[0m"
    read -p "Username: " username || exit 0
    if ! [[ "$username" =~ ^[a-z][a-z0-9_]{0,31}$ ]]; then
        echo -e "\033[0;31mUsername must be lowercase alphanumeric/underscore, start with a letter, max 32 chars.\033[0m"
        read -n 1 -s -r -p "Press any key to return"
        add_ssh
        return
    fi
    if id "$username" &>/dev/null; then
        echo -e "\033[0;31mUser '$username' already exists.\033[0m"
        read -n 1 -s -r -p "Press any key to return"
        add_ssh
        return
    fi
    read -p "Password: " password
    while [ -z "$password" ]; do
        echo -e "\033[0;31mPassword cannot be empty.\033[0m"
        read -p "Password: " password || exit 1
    done
    echo ""
    echo -e "\033[38;5;208m0 not allowed\033[0m"
    read -p "Limit IP: " iplimit
    while ! [[ "$iplimit" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Limit IP: " iplimit || exit 1
    done
    read -p "Expired (days): " masaaktif
    while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Expired (days): " masaaktif || exit 1
    done

    clear_screen

    if [[ "$iplimit" -gt 0 ]]; then
        local limit_dir="/etc/xray/limit/ip/ssh"
        mkdir -p "$limit_dir"
        echo "$iplimit" > "${limit_dir}/${username}"
    fi

    local expiration_date=$(calculate_expiration_date "$masaaktif")
    create_ssh_user "$username" "$password" "$expiration_date" || return

    local expiry=$(chage -l "$username" | grep "Account expires" | awk -F": " '{print $2}' | xargs)

    local message=$(cat <<EOF
-------------------
    SSH Account
-------------------
Domain     : ${rdomain}
Domains    : $alldom
Username   : $username
Password   : $password
Expired    : $expiry
Limit IP   : $iplimit
-------------------
DNS        : 1.1.1.1 / 8.8.8.8
Pub Key    : $pub_key
Nameserver : $nameserver
-------------------
OpenSSH    : 22, 3303
Dropbear   : 111, 109
NonTLS     : 80, 8880, 2052, 2082, 2086, 2095
Enhanced   : 2080
HTTP Proxy : 3128 ( Limit IP to Server )
OHP        : 9088
WS TLS     : 443, 2053, 2083, 2087, 2096
STUNNEL5   : 777
Slowdns    : 53
Udp Custom : 1-65535
Udp Request: 1-65535
BadVpn/Udpgw : 7300
-------------------
OVPN WS     : 2086
OVPN TCP/UDP: 1194 / 2200
Config OVPN : \`http://${domain}/web/openvpn.zip\`
-------------------
EOF
)

    send_telegram_notification "$chat_id" "$key" "$message"

    local log_dir="/var/log/create/ssh"
    mkdir -p "$log_dir"
    echo "$message" > "${log_dir}/${username}.log"

    clear_screen
    source /etc/funny/format.sh
    format_display "$message"
}

main
