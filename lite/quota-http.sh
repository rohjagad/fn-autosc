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
    SKIP_AUTH=""
    [ -z "$PERMISSION_DATA" ] && { echo "Auth sources unreachable - continuing without license check."; SKIP_AUTH=1; USERNAME="(unlicensed)"; PERMISSION_IP="$LOCAL_IP"; }

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep -wF "$LOCAL_IP")
    if [ -z "$MATCH" ] && [ -z "$SKIP_AUTH" ]; then
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
    if [ -n "$SKIP_AUTH" ] || [ "$EXPIRED_DATE" = "lifetime" ]; then
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

# Fungsi untuk mengirim log ke Telegram
function send_log() {
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    URL="https://api.telegram.org/bot${KEY}/sendMessage"

    TEXT="
<code>--------------------</code>
<b> NOTIF QUOTA HTTP UP HABIS</b>
<code>--------------------</code>
<code>Username  : </code><code>${user}</code>
<code>Usage     : </code><code>${total_usage}</code>
<code>Limit     : </code><code>${total_limit}</code>
<code>Status    : </code><code>Deleted</code>
<code>--------------------</code>
"
    curl -s --max-time 10 -X POST "$URL" -d "chat_id=${CHATID}&parse_mode=html" --data-urlencode "text=${TEXT}" >/dev/null
}

# Fungsi untuk mengonversi byte ke format manusiawi
function con() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.2f KB\n" "$(bc -l <<< "scale=2; $bytes/1024")"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.2f MB\n" "$(bc -l <<< "scale=2; $bytes/1048576")"
    elif [[ $bytes -lt 1099511627776 ]]; then
        printf "%.2f GB\n" "$(bc -l <<< "scale=2; $bytes/1073741824")"
    elif [[ $bytes -lt 1125899906842624 ]]; then
        printf "%.2f TB\n" "$(bc -l <<< "scale=2; $bytes/1099511627776")"
    else
        printf "%.2f PB\n" "$(bc -l <<< "scale=2; $bytes/1125899906842624")"
    fi
}

# Fungsi untuk memeriksa penggunaan HTTP
function cekhttp() {
    users=$(grep '^###' /etc/xray/json/upgrade.json | cut -d ' ' -f 2 | sort | uniq)

    need_restart=
    exec 9>/tmp/xray-json-upgrade.lock
    if flock -w 30 9; then
    for user in $users; do
        # Ambil statistik penggunaan dari Xray API
        inb=$(xray api stats --server=127.0.0.1:10081 -name "user>>>${user}>>>traffic>>>uplink" 2>/dev/null | grep value | awk '{gsub(/[",]/,"",$2); print $2}')
        outb=$(xray api stats --server=127.0.0.1:10081 -name "user>>>${user}>>>traffic>>>downlink" 2>/dev/null | grep value | awk '{gsub(/[",]/,"",$2); print $2}')

        # Validasi data inb dan outb
        if [[ -z "$inb" || -z "$outb" ]]; then
            # No counters for this user in this interval - nothing to charge.
            # Stay quiet: the old message spammed the journal every 30s per idle
            # account (Fix 115 extended to all transports).
            continue
        fi

        quota_used=$((inb + outb))
        usage_file="/etc/xray/quota/http/${user}_usage"
        quota_file="/etc/xray/quota/http/${user}"

        if [ -f "$usage_file" ]; then
            previous_usage=$(cat "$usage_file")
            [[ "$previous_usage" =~ ^[0-9]+$ ]] && quota_used=$((quota_used + previous_usage))
        fi
        echo "$quota_used" > "$usage_file"

        if [[ -f "$quota_file" ]]; then
        quota_limit=$(cat "$quota_file")
        if [[ "$quota_used" -gt "$quota_limit" ]]; then
            echo "$(date '+%F %T') quota-http: deleted $user (usage $quota_used > quota $quota_limit)" >> /etc/xray/.quota.logs
            exp=$(grep -w "^### $user" "/etc/xray/json/upgrade.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/upgrade.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/upgrade.json
            total_usage=$(con "$quota_used")
            total_limit=$(con "$quota_limit")
            send_log
            rm -f "$usage_file" "$quota_file"
            rm -f /var/log/create/xray/http/${user}.log
            rm -f /etc/xray/limit/ip/xray/http/${user}
            need_restart=1
            echo "User $user reached quota limit and has been deleted."
        fi
        fi

        # Reset statistik
        xray api stats --server=127.0.0.1:10081 -name "user>>>${user}>>>traffic>>>downlink" -reset >/dev/null 2>&1
        xray api stats --server=127.0.0.1:10081 -name "user>>>${user}>>>traffic>>>uplink" -reset >/dev/null 2>&1
    done
    # One restart per pass, not per deleted user (Found 329 class).
    if [ -n "$need_restart" ]; then
        if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then
            systemctl restart xray@upgrade
        fi
    fi
    flock -u 9
    else
        echo "quota-http: /etc/xray/json/upgrade.json busy, skipping this pass"
    fi
}

# Fungsi utama untuk memonitor HTTP secara terus-menerus
function http() {
    while true; do
        sleep 30
        cekhttp
    done
}

# Eksekusi fungsi utama
http
