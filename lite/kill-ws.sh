#!/bin/bash
# Found 525: license is enforced only for create/extend/install.
# Found 532: cron has no terminal; suppress output so the root mailbox stays quiet.
if [ ! -t 1 ]; then exec >/dev/null 2>&1; fi

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
echo ""
echo ""
function send_log() {
    local user=$1
    local limit=$2
    local total=$3
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    TIME="10"
    TEXT="
<code>--------------------</code>
<b>LIMIT QUOTA WebSocket</b>
<code>--------------------</code>
<code>Username  : </code><code>$user</code>
<code>Limit     : </code><code>$limit</code>
<code>Total    : </code><code>$total</code>
<code>Status   : </code><code>Deleted</code>
<code>--------------------</code>
"
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" "https://api.telegram.org/bot$KEY/sendMessage" >/dev/null
}

function human_readable() {
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

function check_quota() {
    local user=$1
    quota_file="/etc/xray/quota/ws/${user}"
    usage_file="/etc/xray/quota/ws/${user}_usage"
    log_file="/var/log/create/xray/ws/${user}.log"

    if [[ ! -f "$quota_file" ]]; then
        # No quota file = unlimited quota if log exists, skip user
        if [[ -f "$log_file" ]]; then
            return
        fi
        exp=$(grep -w "^### $user" "/etc/xray/json/ws.json" | awk '{print $3}' | sort | uniq | head -n 1)
        if [[ -n "$exp" ]]; then
            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/ws.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
            need_restart=1
        fi

        echo -e "User tanpa file kuota ditemukan
        -----------------
        Username: $user
        Status: Deleted (Quota File Missing)
        -----------------
        " >> /etc/xray/.quota.logs

        send_log "$user" "File Kuota Tidak Ada" "N/A"

        rm -rf "$usage_file"
        rm -fr "$log_file"
        rm -f "/etc/xray/limit/ip/xray/ws/${user}"
        return
    fi

    if [[ -f "$quota_file" && -f "$usage_file" ]]; then
        quota_limit=$(cat "$quota_file")
        usage=$(cat "$usage_file")
        if ! [[ "$usage" =~ ^[0-9]+$ && "$quota_limit" =~ ^[0-9]+$ ]]; then
            continue
        fi

        if [[ $usage -ge $quota_limit ]]; then
            exp=$(grep -w "^### $user" "/etc/xray/json/ws.json" | awk '{print $3}' | sort | uniq | head -n 1)
            if [[ -n "$exp" ]]; then
                sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/ws.json
                sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
                need_restart=1
            fi

            readable_limit=$(human_readable "$quota_limit")
            readable_usage=$(human_readable "$usage")
            echo -e "Limit Quota Access
            -----------------
            Username: $user
            Limit Quota: $readable_limit
            Total Usage: $readable_usage
            Status: deleted
            -----------------
            " >> /etc/xray/.quota.logs

            # Found 500: finish ALL file removals BEFORE the blocking
            # Telegram call (same race as limit-ip-* vs auto-delete-*).
            rm -rf "$quota_file"
            rm -rf "$usage_file"
            rm -fr "$log_file"
            rm -f "/etc/xray/limit/ip/xray/ws/${user}"

            send_log "$user" "$readable_limit" "$readable_usage"
        fi
    fi
}

function process_quota() {
    users=$(grep '^###' /etc/xray/json/ws.json | cut -d ' ' -f 2 | sort | uniq)

    for user in $users; do
        check_quota "$user"
    done
}

exec 9>/tmp/xray-json-ws.lock
if flock -w 30 9; then
process_quota
# One restart per run, not per deleted user (Found 329 class).
if [ -n "$need_restart" ]; then
    if xray run -test -config /etc/xray/json/ws.json >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl restart xray@ws
    fi
fi
flock -u 9
else
    echo "kill-ws: /etc/xray/json/ws.json busy, skipping this run"
fi
exec 9>&-

> /var/log/xray/ws.log
