#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Found 533: systemd services have no TTY; skip clear and keep the journal clean.
[ -t 1 ] && clear || true
echo ""
echo ""
# Fungsi untuk mengirim log ke Telegram
function send_log() {
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    URL="https://api.telegram.org/bot${KEY}/sendMessage"

    TEXT="
<code>--------------------</code>
<b>HTTP UP Quota Exhausted</b>
<code>--------------------</code>
<code>Username  : </code><code>${user}</code>
<code>Usage     : </code><code>${total_usage}</code>
<code>Limit     : </code><code>${total_limit}</code>
<code>Status   : </code><code>Deleted</code>
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
        if ! [[ "$inb" =~ ^[0-9]+$ && "$outb" =~ ^[0-9]+$ ]]; then
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
        if ! [[ "$quota_limit" =~ ^[0-9]+$ ]]; then
            continue
        fi
        if [[ "$quota_used" -gt "$quota_limit" ]]; then
            echo "$(date '+%F %T') quota-http: deleted $user (usage $quota_used > quota $quota_limit)" >> /etc/xray/.quota.logs
            exp=$(grep -w "^### $user" "/etc/xray/json/upgrade.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/upgrade.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/upgrade.json
            total_usage=$(con "$quota_used")
            total_limit=$(con "$quota_limit")
            # Found 500: removals BEFORE notify (same race as limit-ip-*).
            rm -f "$usage_file" "$quota_file"
            rm -f /var/log/create/xray/http/${user}.log
            rm -f /etc/xray/limit/ip/xray/http/${user}
            send_log
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
