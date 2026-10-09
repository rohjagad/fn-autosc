#!/bin/bash

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
clear
echo ""
echo ""
# General TUI theme (same as menu-ssh / x-ws)
red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
NC='\033[0m'

rainbow_sep() {
  local text="${1:------------------------------------}"
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

separator=$(rainbow_sep '-----------------------------------')
blue_sep="${blue}-----------------------------------${NC}"

echo -e "${NC}${separator}
          SSH USER LOGIN
${separator}"

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

# 3-column table, no pipe separators, equal gaps (4 spaces) between columns
function show_logins {
    local rows=() user LIMIT_IP user_count l wu=8 wl=5 fmt
    for user in $(sed -n "s/.*Password auth succeeded for '\([^']*\)' from.*/\1/p" "$DB_SRC" 2>/dev/null | sort -u); do
        [ -n "$user" ] || continue
        LIMIT_IP=$(get_limit_ip "$user" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        user_count=$(grep -c "for '$user' from" "$DB_SRC" 2>/dev/null || echo 0)
        l="${user_count} / ${LIMIT_IP}"
        rows+=("${user}|${l}|Dropbear")
        (( ${#user} > wu )) && wu=${#user}
        (( ${#l} > wl )) && wl=${#l}
    done
    for user in $(sed -n "s/.*Accepted password for \([^ ]*\) from .*/\1/p" "$SSH_SRC" 2>/dev/null | sort -u); do
        [ -n "$user" ] || continue
        LIMIT_IP=$(get_limit_ip "$user" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        user_count=$(grep -c "for $user from" "$SSH_SRC" 2>/dev/null || echo 0)
        l="${user_count} / ${LIMIT_IP}"
        rows+=("${user}|${l}|Openssh")
        (( ${#user} > wu )) && wu=${#user}
        (( ${#l} > wl )) && wl=${#l}
    done
    fmt="%-${wu}s    %-${wl}s    %s\n"
    # shellcheck disable=SC2059
    printf "${purple}${fmt}${NC}" "Username" "Login" "Type"
    echo -e "${blue_sep}"
    for r in ${rows[@]+"${rows[@]}"}; do
        printf "$fmt" "${r%%|*}" "$(echo "$r" | cut -d'|' -f2)" "${r##*|}"
    done
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
        echo "No Limit"
    fi
}

# Fungsi untuk menampilkan total aktif user
function show_total_users {
    local uniq_db uniq_ssh
    uniq_db=$(sed -n "s/.*Password auth succeeded for '\([^']*\)' from.*/\1/p" "$DB_SRC" 2>/dev/null | sort -u | wc -l)
    uniq_ssh=$(sed -n "s/.*Accepted password for \([^ ]*\) from .*/\1/p" "$SSH_SRC" 2>/dev/null | sort -u | wc -l)
    total_users=$((uniq_db + uniq_ssh))
    echo -e "${separator}
${purple}Total Active Users: ${green}$total_users${NC}
${separator}"
}

# Bug 70/71: count both daemons' events (dropbear logins were invisible)
show_logins
show_total_users
rm -f "$DB_SRC" "$SSH_SRC" /tmp/login-ssh.txt /tmp/login-db.txt
