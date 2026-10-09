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
# Function Send Log
send_log() {
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%d-%b-%Y %H:%M:%S")

        TEXT="
<b>-----------------------</b>
<b>MULTILOGIN LOCKED</b>
<b>-----------------------</b>
<code>Date     : $DATE</code>
<code>Username : $user</code>
<code>Protocol : $proto</code>
<code>Transport: GRPC</code>
<code>Login    : $cek / $limit</code>
<code>Status   : Locked</code>
<b>-----------------------</b>
<i>Catatan:</i> The user account has been locked and total usage bandwidth will not be reset on the server. The account will be automatically unlocked in 15 minutes."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Database
username=$(grep '^###' /etc/xray/json/grpc.json | cut -d ' ' -f 2 | sort | uniq)

# Bug 69 regression guard: probe online-session statistics once before looping
# so a transport whose stats service is unavailable exits cleanly instead of
# raising integer-expression errors on every cron run. All four transports are
# served by Xray (see is-decision.md section 13), so this probe answers; the
# guard is kept in case a transport is ever pointed at a stats-less core again.
if ! xray api statsonline --server=127.0.0.1:10083 -email probe 2>&1 | grep -q "not found"; then
    echo "IP limit check skipped: online statistics unavailable on 127.0.0.1:10083"
    exit 0
fi

exec 9>/tmp/xray-json-grpc.lock
if flock -w 30 9; then
for user in $username; do
    # Get the limit and current online stats for each user
    limit=$(cat "/etc/xray/limit/ip/xray/grpc/${user}" 2>/dev/null)
    # Bug 68 guard: 0 / missing / malformed limit = unlimited, never enforced
    if ! [[ "$limit" =~ ^[1-9][0-9]*$ ]]; then
        continue
    fi
    cek=$(xray api statsonline --server=127.0.0.1:10083 -email "$user" 2>/dev/null | jq -r '.stat.value // empty' 2>/dev/null)
    # Skip when the online count is not a number (API error / unavailable)
    if ! [[ "$cek" =~ ^[0-9]+$ ]]; then
        continue
    fi
    
    # Clear screen
    clear
    echo ""
    echo ""
    # Check if usage exceeds limit
    if [[ "$cek" -gt "$limit" ]]; then
        # Deleted Account
        # Bug 68: the legacy range pattern /^### $user $exp/,/^},{/d never
        # matched its end address (no line starts with "},{") while $exp was
        # undefined, so a triggered limit deleted the account block plus
        # everything after it to the end of the file. Remove only the account.
        exp=$(grep -wE "^### $user" "/etc/xray/json/grpc.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
    proto=$(grep -E "^(Protokol|Protocol) *:" "/var/log/create/xray/grpc/${user}.log" | awk '{print $NF}'); proto=${proto^^}
        if [[ -n "$exp" ]]; then
            sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/grpc.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/grpc.json
            need_restart=1
            send_log
            mv /var/log/create/xray/grpc/${user}.log /var/log/create/xray/grpc/${user}.locked
            mkdir -p /etc/xray/autounlock/grpc
            echo $(( $(date +%s) + 600 )) > /etc/xray/autounlock/grpc/$user
        fi

    else
        # If within limit, just clear the screen and display a message
        clear
        echo ""
        echo ""
    fi
done

# Auto-unlock sweeper: multilogin state written at lock time carries
# the due epoch (lock + 10 min, so the unlock lands within 15 min on
# the 5-minute cron). Manual locks never write state, so they stay
# indefinite. Shares this flock and the single restart below.
for _sf in /etc/xray/autounlock/grpc/*; do
    [ -e "$_sf" ] || continue
    _au=$(basename "$_sf")
    if [ ! -f "/var/log/create/xray/grpc/${_au}.locked" ]; then
        rm -f "$_sf"
        continue
    fi
    _due=$(cat "$_sf" 2>/dev/null)
    if [[ "$_due" =~ ^[0-9]+$ ]] && [ "$(date +%s)" -ge "$_due" ]; then
        rm -f "$_sf"
        XRAY_BATCH=1 "/usr/bin/unlock-grpc-auto" "$_au"
        [ "$?" -eq 2 ] && need_restart=1
    fi
done

# One restart per run, not per locked user: N triggered users used
# to mean N back-to-back restarts and tripped the start limiter.
if [ -n "$need_restart" ]; then
    if xray run -test -config /etc/xray/json/grpc.json >/dev/null 2>&1; then
        systemctl restart xray@grpc >> /dev/null 2>&1
    fi
fi
flock -u 9
else
    echo "limit-ip-grpc: /etc/xray/json/grpc.json busy, skipping this run"
fi
exec 9>&-
