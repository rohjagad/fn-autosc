#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
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
<b>XHTTP Quota Exhausted</b>
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

# Fungsi untuk memeriksa penggunaan xhttp
function cekxhttp() {
    users=$(grep '^###' /etc/xray/json/xhttp.json | cut -d ' ' -f 2 | sort | uniq)

    # Found 524: collect counters and update usage files WITHOUT the shared
    # JSON lock.  The Xray API is the slow/fragile part; holding
    # /tmp/xray-json-xhttp.lock across it made xp, kill-xhttp and
    # limit-ip-xhttp report "busy" whenever one stats call stalled.  Usage
    # files are owned by this daemon, so they do not need the JSON lock.
    declare -A over_quota=()
    for user in $users; do
        # Ambil statistik penggunaan dari Xray API
        inb=$(timeout 10 xray api stats --server=127.0.0.1:10082 -name "user>>>${user}>>>traffic>>>uplink" 2>/dev/null | grep value | awk '{gsub(/[",]/,"",$2); print $2}')
        outb=$(timeout 10 xray api stats --server=127.0.0.1:10082 -name "user>>>${user}>>>traffic>>>downlink" 2>/dev/null | grep value | awk '{gsub(/[",]/,"",$2); print $2}')

        # Validasi data inb dan outb
        if ! [[ "$inb" =~ ^[0-9]+$ && "$outb" =~ ^[0-9]+$ ]]; then
            # No counters for this user in this interval - nothing to charge.
            # Stay quiet: the old message spammed the journal every 30s per idle
            # account (Fix 115 extended to all transports).
            # Found 524: initialize a zero usage file for an idle account that
            # has a quota, so cek-xray-xhttp shows 0 B instead of "Not
            # available". Real counters replace it on the next pass.
            if [ -f "/etc/xray/quota/xhttp/${user}" ] && [ ! -f "/etc/xray/quota/xhttp/${user}_usage" ]; then
                echo 0 > "/etc/xray/quota/xhttp/${user}_usage"
            fi
            continue
        fi

        quota_used=$((inb + outb))
        usage_file="/etc/xray/quota/xhttp/${user}_usage"
        quota_file="/etc/xray/quota/xhttp/${user}"

        if [ -f "$usage_file" ]; then
            previous_usage=$(cat "$usage_file")
            [[ "$previous_usage" =~ ^[0-9]+$ ]] && quota_used=$((quota_used + previous_usage))
        fi
        echo "$quota_used" > "$usage_file"

        if [[ -f "$quota_file" ]]; then
            quota_limit=$(cat "$quota_file")
            if [[ "$quota_limit" =~ ^[0-9]+$ ]] && [ "$quota_used" -gt "$quota_limit" ]; then
                over_quota["$user"]="$quota_used $quota_limit"
            fi
        fi

        # Reset statistik
        timeout 10 xray api stats --server=127.0.0.1:10082 -name "user>>>${user}>>>traffic>>>downlink" -reset >/dev/null 2>&1
        timeout 10 xray api stats --server=127.0.0.1:10082 -name "user>>>${user}>>>traffic>>>uplink" -reset >/dev/null 2>&1
    done

    need_restart=
    declare -a notify_users=() notify_usage=() notify_limit=()

    # Found 524: only JSON/file mutations need the shared lock.  Keep this
    # section short: no API calls, no Telegram, no service restart.
    if [ ${#over_quota[@]} -gt 0 ]; then
        exec 9>/tmp/xray-json-xhttp.lock
        if flock -w 10 9; then
            for user in "${!over_quota[@]}"; do
                read -r quota_used quota_limit <<< "${over_quota[$user]}"
                usage_file="/etc/xray/quota/xhttp/${user}_usage"
                quota_file="/etc/xray/quota/xhttp/${user}"
                exp=$(grep -w "^### $user" "/etc/xray/json/xhttp.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
                if [ -z "$exp" ]; then
                    # A multilogin lock removes the JSON entry temporarily.
                    # Keep quota/limit/usage files so auto-unlock restores a
                    # complete account; only clean files for a real deletion.
                    if [ -f "/var/log/create/xray/xhttp/${user}.locked" ] || [ -f "/etc/xray/autounlock/xhttp/${user}" ]; then
                        continue
                    fi
                    # Account already removed by xp/limit-ip: clean orphans,
                    # but do not send a duplicate quota notice.
                    rm -f "$usage_file" "$quota_file"
                    rm -f "/var/log/create/xray/xhttp/${user}.log"
                    rm -f "/etc/xray/limit/ip/xray/xhttp/${user}"
                    continue
                fi
                echo "$(date '+%F %T') quota-xhttp: deleted $user (usage $quota_used > quota $quota_limit)" >> /etc/xray/.quota.logs
                sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/xhttp.json
                sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/xhttp.json
                # Found 500: removals BEFORE notify (same race as limit-ip-*).
                rm -f "$usage_file" "$quota_file"
                rm -f "/var/log/create/xray/xhttp/${user}.log"
                rm -f "/etc/xray/limit/ip/xray/xhttp/${user}"
                notify_users+=("$user")
                notify_usage+=("$quota_used")
                notify_limit+=("$quota_limit")
                need_restart=1
                echo "User $user reached quota limit and has been deleted."
            done
            # One restart per pass, not per deleted user (Found 329 class).
            if [ -n "$need_restart" ]; then
                if ! xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then
                    need_restart=
                fi
            fi
            flock -u 9
        else
            echo "quota-xhttp: /etc/xray/json/xhttp.json busy, skipping this pass"
        fi
        exec 9>&-
    fi

    # Found 524: Telegram and the single restart are outside the lock.  A slow
    # notification must never make xp/limit-ip-xhttp/kill-xhttp wait.
    local i
    for i in "${!notify_users[@]}"; do
        user="${notify_users[$i]}"
        total_usage=$(con "${notify_usage[$i]}")
        total_limit=$(con "${notify_limit[$i]}")
        send_log
    done
    if [ -n "$need_restart" ]; then
        timeout 60 systemctl restart xray@xhttp
    fi
}

# Fungsi utama untuk memonitor xhttp secara terus-menerus
function xhttp() {
    while true; do
        sleep 30
        cekxhttp
    done
}

# Eksekusi fungsi utama
xhttp
