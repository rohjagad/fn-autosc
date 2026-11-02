#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

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
<code>Transport: XHTTP</code>
<code>Login    : $cek / $limit</code>
<code>Status   : Locked</code>
<b>-----------------------</b>
${_ipline}
$_ipblock
<b>-----------------------</b>
<i>Catatan:</i> The user account has been locked and total usage bandwidth will not be reset on the server. The account will be automatically unlocked after at least 15 minutes."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Database
username=$(grep '^###' /etc/xray/json/xhttp.json | cut -d ' ' -f 2 | sort | uniq)

# Bug 69 regression guard: probe online-session statistics once before looping
# so a transport whose stats service is unavailable exits cleanly instead of
# raising integer-expression errors on every cron run. All four transports are
# served by Xray (see is-decision.md section 13), so this probe answers; the
# guard is kept in case a transport is ever pointed at a stats-less core again.
if ! xray api statsonline --server=127.0.0.1:10082 -email probe 2>&1 | grep -q "not found"; then
    echo "IP limit check skipped: online statistics unavailable on 127.0.0.1:10082"
    exit 0
fi

need_restart=0
tmp=$(mktemp -d /tmp/limit-ip-xhttp.XXXXXX) || { echo "limit-ip-xhttp: cannot create temp dir"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/candidates"

# Found 524: collect IP evidence WITHOUT the shared JSON lock.  The Xray
# stats calls are the slow/fragile part; holding /tmp/xray-json-xhttp.lock
# across them made xp/kill-xhttp/quota-xhttp report "busy" whenever a call
# stalled.  The outer /tmp/limit-ip-xhttp.lock already prevents overlapping
# limit-ip-xhttp runs, so the per-user state files are safe here.
for user in $username; do
    # Get the limit and current online stats for each user
    limit=$(cat "/etc/xray/limit/ip/xray/xhttp/${user}" 2>/dev/null)
    _state="/var/lib/fn-autosc/limit-ip/xhttp/${user}"
    # Bug 68 guard: 0 / missing / malformed limit = unlimited, never enforced
    if ! [[ "$limit" =~ ^[1-9][0-9]*$ ]]; then
        rm -f "$_state"
        continue
    fi

    # Found 508: statsonlineiplist exposes the actual per-IP map. The old
    # statsonline count alone cannot tell real multi-device use from one
    # CGNAT device rotating addresses, and the access log is truncated by
    # kill-ws every 5 minutes (which produced the misleading "IPs (0)").
    # Merge both sources: the map covers idle sessions, the 1-minute log
    # covers a map that is momentarily empty. The 5-minute stability gate
    # below stops a handover address from becoming a stable extra IP.
    _iplist=$(timeout 10 xray api statsonlineiplist --server=127.0.0.1:10082 -email "$user" 2>/dev/null | jq -r 'if (.ips|type)=="object" then (.ips|keys[]) else empty end' 2>/dev/null | sed -e 's/^\[//' -e 's/\]$//' | sort -u)
    _statc=$(timeout 10 xray api statsonline --server=127.0.0.1:10082 -email "$user" 2>/dev/null | jq -r '.stat.value // empty' 2>/dev/null)
    [[ "$_statc" =~ ^[0-9]+$ ]] || _statc=0
    _cut=$(date -d '1 minute ago' '+%Y/%m/%d %H:%M:%S')
    _logips=$(awk -v cut="$_cut" -v u="$user" '$1" "$2 >= cut && match($0, "email: "u"([^A-Za-z0-9_]|$)") {for(i=1;i<=NF;i++) if($i=="from"){s=$(i+1); sub(/^(tcp|udp):/,"",s); sub(/:[0-9]*$/,"",s); sub(/^\[/,"",s); sub(/\]$/,"",s); if(s!="") print s; break}}' "/var/log/xray/xhttp.log" 2>/dev/null | sort -u)
    _curips=$(printf '%s\n%s\n' "$_iplist" "$_logips" | sed '/^$/d' | sort -u)
    if [ -n "$_curips" ]; then
        _ipc=$(printf '%s\n' "$_curips" | wc -l)
        _ipblock=$(printf '%s\n' "$_curips" | sed 's/.*/<code>&<\/code>/')
        _ipline="<code>IPs (${_ipc}):</code>"
    else
        _ipc=0
        _ipblock="<code>-</code>"
        _ipline="<code>IPs: evidence unavailable (stats empty, log rotated)</code>"
        if [ "$_statc" -gt "$limit" ]; then
            echo "IP limit: $user statsonline=$_statc but no IP evidence; skipping lock this cycle"
        fi
    fi
    [[ "$_ipc" =~ ^[0-9]+$ ]] || _ipc=0
    cek="$_ipc"

    # Found 509: CGNAT handover can make one device look like N IPs for a
    # few seconds. Lock only when the SAME over-limit IP set is seen on two
    # consecutive 5-minute runs (>=240s), so a rotating address never forms
    # a stable set. The state is a two-sample gate only; it never fabricates
    # IP evidence when both the map and the log are empty.
    if [ "$_ipc" -gt "$limit" ]; then
        _prev_epoch=""
        _prev_ips=""
        if [ -f "$_state" ]; then
            _prev_epoch=$(sed -n '1p' "$_state" 2>/dev/null)
            _prev_ips=$(sed -n '2,$p' "$_state" 2>/dev/null)
        fi
        if [ "$_curips" = "$_prev_ips" ] && [[ "$_prev_epoch" =~ ^[0-9]+$ ]]; then
            if [ $(( $(date +%s) - _prev_epoch )) -ge 240 ]; then
                # Stable second sample: queue the lock. Keep the state file
                # until the deletion succeeds (removed under the lock below).
                :
            else
                # Same set, not old enough: keep the original epoch so a
                # frequent manual run cannot reset the grace forever.
                echo "IP limit: $user has $_ipc IPs (> $limit), waiting for a stable second sample"
                continue
            fi
        else
            mkdir -p "$(dirname "$_state")"
            { echo "$(date +%s)"; printf '%s\n' "$_curips"; } > "$_state"
            echo "IP limit: $user has $_ipc IPs (> $limit), waiting for a stable second sample"
            continue
        fi
    else
        rm -f "$_state"
    fi

    if [[ "$cek" -gt "$limit" ]]; then
        proto=$(grep -E "^(Protokol|Protocol) *:" "/var/log/create/xray/xhttp/${user}.log" | awk '{print $NF}'); proto=${proto^^}
        printf '%s\t%s\t%s\t%s\n' "$user" "$limit" "$cek" "$proto" >> "$tmp/candidates"
        printf '%s\n' "$_curips" > "$tmp/$user.ips"
    fi
done

# Drop per-user IP-evidence state for accounts that no longer exist.
for _st in /var/lib/fn-autosc/limit-ip/xhttp/*; do
    [ -e "$_st" ] || continue
    _su=$(basename "$_st")
    if ! printf '%s\n' "$username" | grep -qxF -- "$_su"; then
        rm -f "$_st"
    fi
done

# Found 524: JSON/card mutations only inside the shared lock.  No API calls,
# Telegram or service restart in this section.
exec 9>/tmp/xray-json-xhttp.lock
if flock -w 10 9; then
    : > "$tmp/notify"
    while IFS=$'\t' read -r user limit cek proto; do
        [ -n "$user" ] || continue
        _state="/var/lib/fn-autosc/limit-ip/xhttp/${user}"
        _curips=$(cat "$tmp/$user.ips" 2>/dev/null)
        _ipc="$cek"
        _ipblock=$(printf '%s\n' "$_curips" | sed 's/.*/<code>&<\/code>/')
        _ipline="<code>IPs (${_ipc}):</code>"

        # Re-check under the lock: xp/quota-xhttp may have removed it.
        exp=$(grep -wE "^### $user" "/etc/xray/json/xhttp.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
        if [[ -z "$exp" ]]; then
            rm -f "$_state"
            continue
        fi

        sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/xhttp.json
        sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/xhttp.json
        need_restart=1
        rm -f "$_state"
        # Found 500: finish ALL state changes (.log -> .locked + unlock
        # state) BEFORE the blocking Telegram call. auto-delete-* takes
        # no lock; notify-first leaves a window where the card exists
        # without JSON entry or lock, and a concurrent auto-delete run
        # wipes the account ("Log Cleanup") - proven live 2026-10-10
        # (lock + cleanup telegrams stamped the same second).
        mv /var/log/create/xray/xhttp/${user}.log /var/log/create/xray/xhttp/${user}.locked
        mkdir -p /etc/xray/autounlock/xhttp
        echo $(( $(date +%s) + 900 )) > /etc/xray/autounlock/xhttp/$user
        printf '%s\t%s\t%s\t%s\n' "$user" "$limit" "$cek" "$proto" >> "$tmp/notify"
    done < "$tmp/candidates"

    # Auto-unlock sweeper: multilogin state written at lock time carries
    # the due epoch (lock + 15 min; the 5-minute cron can only unlock at or
    # after that, never before). Manual locks never write state, so they
    # stay indefinite. Shares this flock and the single restart below.
    for _sf in /etc/xray/autounlock/xhttp/*; do
        [ -e "$_sf" ] || continue
        _au=$(basename "$_sf")
        if ! [[ "$_au" =~ ^[a-z0-9_]+$ ]]; then
            rm -f "$_sf"
            continue
        fi
        if [ ! -f "/var/log/create/xray/xhttp/${_au}.locked" ]; then
            rm -f "$_sf"
            continue
        fi
        _due=$(cat "$_sf" 2>/dev/null)
        _since=$(stat -c %Y -- "$_sf" 2>/dev/null)
        # Fix 510/515: older builds wrote lock+600, and a partial/corrupt due
        # file must not freeze the lock forever. Fall back to mtime+900, then
        # to now+900 when even the mtime is unavailable.
        if ! [[ "$_due" =~ ^[0-9]+$ ]]; then
            if [[ "$_since" =~ ^[0-9]+$ ]]; then
                _due=$(( _since + 900 ))
            else
                _due=$(( $(date +%s) + 900 ))
            fi
        elif [[ "$_since" =~ ^[0-9]+$ ]] && [ "$_due" -lt $(( _since + 800 )) ]; then
            _due=$(( _since + 900 ))
        fi
        if [[ "$_due" =~ ^[0-9]+$ ]] && [ "$(date +%s)" -ge "$_due" ]; then
            XRAY_BATCH=1 "${UNLOCK_BIN:-/usr/bin/unlock-xhttp-auto}" "$_au"
            _rc=$?
            case "$_rc" in
                0) rm -f "$_sf" ;;
                2) rm -f "$_sf"; need_restart=1 ;;
                *) echo "limit-ip-xhttp: auto-unlock $_au failed (rc=$_rc); will retry" >&2 ;;
            esac
        fi
    done

    # One restart per run, not per locked user: N triggered users used
    # to mean N back-to-back restarts and tripped the start limiter.
    if [ "${need_restart:-0}" -eq 1 ]; then
        if ! xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then
            need_restart=0
        fi
    fi
    flock -u 9
else
    echo "limit-ip-xhttp: /etc/xray/json/xhttp.json busy, skipping this run"
fi
exec 9>&-

# Found 524: Telegram and the restart are outside the lock.
if [ -s "$tmp/notify" ]; then
    while IFS=$'\t' read -r user limit cek proto; do
        _curips=$(cat "$tmp/$user.ips" 2>/dev/null)
        _ipc="$cek"
        _ipblock=$(printf '%s\n' "$_curips" | sed 's/.*/<code>&<\/code>/')
        _ipline="<code>IPs (${_ipc}):</code>"
        send_log
    done < "$tmp/notify"
fi
if [ "${need_restart:-0}" -eq 1 ]; then
    timeout 60 systemctl restart xray@xhttp >> /dev/null 2>&1
fi
