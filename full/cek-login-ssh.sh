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
clear

# Fungsi untuk mencetak teks dengan warna
function print_color {
    echo -e "\033[1;34m$1\033[0m"  # Biru untuk header
}

# Memeriksa apakah file log tersedia
LOG=""
if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
else
    echo "Log file not found!"
    exit 1
fi

# Bug 70/71: same log-source and log-format fixes as limit-ip-ssh.sh - on
# Debian 12 dropbear (the daemon serving SSH accounts) only logs to the
# systemd journal so /var/log/auth.log has zero dropbear lines, and rsyslog
# writes RFC3339 timestamps the old fixed field offsets cannot parse. Pull
# dropbear from the journal when available and parse both formats from the
# message body.
DB_SRC=$(mktemp)
SSH_SRC=$(mktemp)
grep -E "Password auth succeeded" "$LOG" > "$DB_SRC"
if command -v journalctl >/dev/null 2>&1 && journalctl -u dropbear -n 20 --no-pager 2>/dev/null | grep -q .; then
    journalctl -u dropbear -n 10000 --no-pager 2>/dev/null | grep -E "Password auth succeeded" > "$DB_SRC"
fi
grep -E "Accepted password for" "$LOG" > "$SSH_SRC"
countdb=$(wc -l < "$DB_SRC")
countsh=$(wc -l < "$SSH_SRC")

# Fungsi untuk menampilkan login Dropbear dengan PID dan Limit IP
function show_dropbear_logins {
    print_color "═══════════[ Dropbear User Login ]═══════════"
    printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "Username" "IP Address" "Login Count" "PID" "Limit IP"
    echo "──────────────────────────────"
    while IFS= read -r line; do
        # Bug 70/71: message-body parse - works for classic and RFC3339 prefixes
        user=$(sed -n "s/.*Password auth succeeded for '\([^']*\)' from.*/\1/p" <<< "$line")
        hostport=$(sed -n "s/.*Password auth succeeded for '[^']*' from \([^ ]*\).*/\1/p" <<< "$line")
        [ -n "$user" ] || continue

        # Mendapatkan limit IP dari file terkait
        LIMIT_IP=$(get_limit_ip "$user")

        # PID dari tag dropbear[PID]
        PID=$(sed -n "s/.*dropbear\[\([0-9][0-9]*\)\].*/\1/p" <<< "$line")

        if [ -z "$PID" ]; then
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$hostport" "$countdb" "N/A" "$LIMIT_IP"
        else
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$hostport" "$countdb" "$PID" "$LIMIT_IP"
        fi
    done < "$DB_SRC"
    echo ""
}

# Fungsi untuk menampilkan login OpenSSH dengan PID dan Limit IP
function show_openssh_logins {
    print_color "═══════════[ OpenSSH User Login ]═══════════"
    printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "Username" "IP Address" "Login Count" "PID" "Limit IP"
    echo "──────────────────────────────"
    while IFS= read -r line; do
        # Bug 70/71: message-body parse - works for classic and RFC3339 prefixes
        user=$(sed -n "s/.*Accepted password for \([^ ]*\) from .*/\1/p" <<< "$line")
        ip=$(sed -n "s/.*Accepted password for [^ ]* from \([^ ]*\) port.*/\1/p" <<< "$line")
        [ -n "$user" ] || continue

        # Mendapatkan limit IP dari file terkait
        LIMIT_IP=$(get_limit_ip "$user")

        # PID dari tag sshd[PID]
        PID=$(sed -n "s/.*sshd\[\([0-9][0-9]*\)\].*/\1/p" <<< "$line")

        if [ -z "$PID" ]; then
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countsh" "N/A" "$LIMIT_IP"
        else
            printf "%-20s| %-20s| %-12s| %-8s| %-8s\n" "$user" "$ip" "$countsh" "$PID" "$LIMIT_IP"
        fi
    done < "$SSH_SRC"
    echo ""
}

# Fungsi untuk mendapatkan Limit IP dari file tertentu
function get_limit_ip {
    USER=$1
    LIMIT_FILE="/etc/xray/limit/ip/ssh/$USER"

    if [ -f "$LIMIT_FILE" ]; then
        LIMIT=$(cat "$LIMIT_FILE")
        if [ "$LIMIT" == "Unlimited" ]; then
            echo "Unlimited"
        else
            echo "$LIMIT"
        fi
    else
        echo "2"  # Default limit
    fi
}

# Fungsi untuk menampilkan total aktif user
function show_total_users {
    total_users=$((countdb + countsh))
    print_color "═══════════════════════════════════════════════"
    print_color "Total Active Users: $total_users"
    print_color "═══════════════════════════════════════════════"
}

# Bug 70/71: count both daemons' events (dropbear logins were invisible)
show_dropbear_logins
show_openssh_logins
rm -f "$DB_SRC" "$SSH_SRC" /tmp/login-ssh.txt /tmp/login-db.txt
show_total_users
