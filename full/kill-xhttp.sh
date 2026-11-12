#!/bin/bash
# Found 525: license is enforced only for create/extend/install.
# Found 532: cron has no terminal; suppress output so the root mailbox stays quiet.
if [ ! -t 1 ]; then exec >/dev/null 2>&1; fi
# Found 531: bound the xHTTP access log.  Fix 545's limit-ip-xhttp reads
# only statsonlineiplist, so the log is diagnostic evidence; a 5-minute
# truncation is safe and stops unbounded growth.

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
<b>LIMIT QUOTA XHTTP</b>
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
    quota_file="/etc/xray/quota/xhttp/${user}"
    usage_file="/etc/xray/quota/xhttp/${user}_usage"

    if [[ -f "$quota_file" && -f "$usage_file" ]]; then
        quota_limit=$(cat "$quota_file")
        usage=$(cat "$usage_file")
        if ! [[ "$usage" =~ ^[0-9]+$ && "$quota_limit" =~ ^[0-9]+$ ]]; then
            return
        fi

        if [[ $usage -ge $quota_limit ]]; then
            candidates+=("$user|$quota_limit|$usage")
        fi
    fi
}

function process_quota() {
    users=$(grep '^###' /etc/xray/json/xhttp.json | cut -d ' ' -f 2 | sort | uniq)

    for user in $users; do
        check_quota "$user"
    done
}

# Found 524: collect candidates outside the shared JSON lock.  Re-check and
# mutate only inside the lock, then notify/restart outside it.
candidates=()
process_quota
need_restart=0
declare -a notify_users=() notify_limits=() notify_usages=()

if [ ${#candidates[@]} -gt 0 ]; then
    exec 9>/tmp/xray-json-xhttp.lock
    if flock -w 10 9; then
        for item in "${candidates[@]}"; do
            IFS='|' read -r user quota_limit usage <<< "$item"
            quota_file="/etc/xray/quota/xhttp/${user}"
            usage_file="/etc/xray/quota/xhttp/${user}_usage"

            # quota-xhttp may have removed the account while we collected.
            [ -f "$quota_file" ] && [ -f "$usage_file" ] || continue
            quota_limit=$(cat "$quota_file")
            usage=$(cat "$usage_file")
            [[ "$usage" =~ ^[0-9]+$ && "$quota_limit" =~ ^[0-9]+$ ]] || continue
            [[ $usage -ge $quota_limit ]] || continue

            exp=$(grep -w "^### $user" "/etc/xray/json/xhttp.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
            if [[ -z "$exp" ]]; then
                # A multilogin lock removes the JSON entry temporarily.
                # Keep quota/limit/usage files so auto-unlock restores a
                # complete account; only clean files for a real deletion.
                if [ -f "/var/log/create/xray/xhttp/${user}.locked" ] || [ -f "/etc/xray/autounlock/xhttp/${user}" ]; then
                    continue
                fi
                # Already removed: clean orphan files, no duplicate notice.
                rm -f "$quota_file" "$usage_file"
                rm -f "/var/log/create/xray/xhttp/${user}.log"
                rm -f "/etc/xray/limit/ip/xray/xhttp/${user}"
                continue
            fi

            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/xhttp.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/xhttp.json
            need_restart=1

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
            rm -f "$quota_file"
            rm -f "$usage_file"
            rm -f "/var/log/create/xray/xhttp/${user}.log"
            rm -f "/etc/xray/limit/ip/xray/xhttp/${user}"

            notify_users+=("$user")
            notify_limits+=("$readable_limit")
            notify_usages+=("$readable_usage")
        done
        # One restart per run, not per deleted user (Found 329 class).
        if [ "$need_restart" -eq 1 ]; then
            if ! xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then
                need_restart=0
            fi
        fi
        flock -u 9
    else
        echo "kill-xhttp: /etc/xray/json/xhttp.json busy, skipping this run"
    fi
    exec 9>&-
fi

# Found 524: notifications and restart never run while holding the lock.
for i in "${!notify_users[@]}"; do
    send_log "${notify_users[$i]}" "${notify_limits[$i]}" "${notify_usages[$i]}"
done
if [ "$need_restart" -eq 1 ]; then
    timeout 60 systemctl daemon-reload
    timeout 60 systemctl restart xray@xhttp
fi

# Found 531: keep /var/log/xray/xhttp.log bounded like ws.log.
> /var/log/xray/xhttp.log
