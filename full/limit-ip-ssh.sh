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
blue='\033[1;34m'
NC='\033[0m'

clear
echo ""
echo ""
# Found 512: the limiter counts unique active client IPs from the shared
# ssh-online helper.  The helper resolves WS/CDN sessions (Dropbear sees
# 127.0.0.1 behind ws:2080) to the real client IP; see full/ssh-online.sh.
# The helper check lives after unlocked() so an ssh-online failure can still
# run the auto-unlock sweeper (Found 515).

mesinssh() {
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
# ==========================================
# Getting
clear
echo ""
echo ""
echo " "
echo " "

# Found 512: one active-session table for both daemons.  The old code parsed
# raw login events, so a user with several sessions from one IP looked like
# several IPs and every WS/CDN session looked like 127.0.0.1.
echo -e "${blue}----------=[ Active SSH Sessions ]=-----------${NC}"
echo "ID  |  Username  |  IP Address  |  Type"
echo -e "${blue}----------------------------------------------${NC}"
awk -F'\t' '{ print $4" - "$1" - "$2" - "$3 }' "$SSH_ONLINE"

# OpenVPN TCP Log
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
    echo ""
    echo -e "${blue}---------=[ OpenVPN TCP User Login ]=---------${NC}"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo -e "${blue}----------------------------------------------${NC}"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
    cat /tmp/vpn-login-tcp.txt
fi

# OpenVPN UDP Log
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
    echo " "
    echo -e "${blue}---------=[ OpenVPN UDP User Login ]=---------${NC}"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo -e "${blue}----------------------------------------------${NC}"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
    cat /tmp/vpn-login-udp.txt
fi
echo -e "${blue}----------------------------------------------${NC}"
echo ""
}

logs() {
    TEKS="
<b>-----------------------</b>
<b>MULTILOGIN LOCKED</b>
<b>-----------------------</b>
<code>Username    : $user</code>
<code>Type        : SSH</code>
<code>Active IPs  : $cekcek / $iplimit</code>
<code>Status      : Locked</code>
<code>Unlock Time : $unlock_time</code>
<b>-----------------------</b>
Active IPs

$ip_list
<b>-----------------------</b>
The account will be locked for 15 minutes and will be unlocked automatically.
"
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "disable_web_page_preview=1" --data-urlencode "parse_mode=html" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's|^[A-Za-z][^:]*: .*|<code>&</code>|')" $URL >/dev/null 2>&1
clear
echo ""
echo ""
}

unlocked() {
    local _u="${1:-}"
    [ -n "$_u" ] || return 0
    local _t=$(date +"%d-%b-%Y %H:%M:%S")
    local _msg="
<b>-----------------------</b>
<b>MULTILOGIN UNLOCKED</b>
<b>-----------------------</b>
<code>Username    : $_u</code>
<code>Type        : SSH</code>
<code>Time        : $_t</code>
<code>Status      : Unlocked</code>
<b>-----------------------</b>
The lock period ended and the account can be used again."
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    TIME="10"
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$_msg" $URL >/dev/null
}

# Found 515: auto-unlock is independent of ssh-online.  A missing/broken
# helper must not freeze every SSH lock forever; run this sweeper before the
# helper check and keep the due file until passwd -u actually succeeds.
ssh_auto_unlock() {
    for _sf in /etc/xray/autounlock/ssh/*; do
        [ -e "$_sf" ] || continue
        _au=$(basename "$_sf")
        if ! [[ "$_au" =~ ^[a-z0-9_]+$ ]]; then
            rm -f "$_sf"
            continue
        fi
        if passwd -S "$_au" 2>/dev/null | grep -q " L "; then
            _due=$(cat "$_sf" 2>/dev/null)
            _since=$(stat -c %Y -- "$_sf" 2>/dev/null)
            # Found 515: a partial/corrupt due file must not freeze the lock
            # forever. Fall back to mtime+900, then to now+900.
            if ! [[ "$_due" =~ ^[0-9]+$ ]]; then
                if [[ "$_since" =~ ^[0-9]+$ ]]; then
                    _due=$(( _since + 900 ))
                else
                    _due=$(( $(date +%s) + 900 ))
                fi
            fi
            if [[ "$_due" =~ ^[0-9]+$ ]] && [ "$(date +%s)" -ge "$_due" ]; then
                if passwd -u "$_au" >/dev/null 2>&1 && \
                    ! passwd -S "$_au" 2>/dev/null | grep -q " L "; then
                    rm -f "$_sf"
                    unlocked "$_au" >/dev/null 2>&1
                else
                    echo "limit-ip-ssh: failed to unlock $_au; will retry" >&2
                fi
            fi
        else
            rm -f "$_sf"
        fi
    done
}

# Found 515: passwd -l blocks new authentications but leaves the over-limit
# sessions running.  The old code restarted ssh/sshd/ws to force them out,
# which dropped every other user too.  Kill only the offending account's
# processes; its Dropbear/OpenSSH children run as that UID, so the sessions
# close while other accounts keep theirs.
ssh_kick_user() {
    local _u="$1"
    command -v pkill >/dev/null 2>&1 || return 0
    pkill -KILL -u "$_u" >/dev/null 2>&1 || true
}

SSH_ONLINE_BIN="${SSH_ONLINE_BIN:-$(command -v ssh-online 2>/dev/null || true)}"
if [ -z "$SSH_ONLINE_BIN" ] || [ ! -x "$SSH_ONLINE_BIN" ]; then
    echo "limit-ip-ssh: ssh-online helper not found; run update.sh." >&2
    ssh_auto_unlock
    exit 1
fi
SSH_ONLINE=$(mktemp) || { echo "limit-ip-ssh: cannot create temporary file." >&2; ssh_auto_unlock; exit 1; }
trap 'rm -f "$SSH_ONLINE"' EXIT
if ! "$SSH_ONLINE_BIN" > "$SSH_ONLINE" 2>/dev/null; then
    echo "limit-ip-ssh: ssh-online failed; no lock changes made." >&2
    ssh_auto_unlock
    exit 1
fi

clear
echo ""
echo ""
# Bug 64: field 3 of /etc/passwd is the UID, field 4 is the GID. The old
# pattern discarded the UID and enrolled every account whose GID >= 1000
# (system accounts such as sync/_apt/sshd) while exempting real users whose
# primary group is below 1000. Match the Go tools (uid >= 1000, uid < 65534).
username=$(while IFS=: read -r username _ uid _ _ _ _; do
    if [[ $uid -ge 1000 && $uid -lt 65534 && $username != "nobody" && $username != "root" ]]; then
        echo "$username"
    fi
done < /etc/passwd)

# Membuat direktori jika belum ada
if [ ! -d "/etc/xray/limit/ip/ssh" ]; then
    mkdir -p "/etc/xray/limit/ip/ssh"
    echo "Direktori /etc/xray/limit/ip/ssh dibuat."
fi

# Bug 64: drop limit files left behind for accounts that are no longer
# enrolled (system users picked up by the old GID-based filter).
for limit_file in /etc/xray/limit/ip/ssh/*; do
    [ -f "$limit_file" ] || continue
    if ! echo "$username" | grep -qx -- "$(basename "$limit_file")"; then
        rm -f "$limit_file"
    fi
done

# Found 512: the 1-minute login-event window is gone.  Count unique active
# client IPs per account from ssh-online, which is also what the menu shows.
mesinssh
date=$(date)
nais=0

for user in $username
do
    file_path="/etc/xray/limit/ip/ssh/$user"
    if [ ! -f "$file_path" ]; then
        echo "2" > "$file_path"
        echo "File untuk pengguna $user dibuat dan diisi dengan 2."
    fi

    # A limit of 0 is rejected by the limit-ip tool (it would lock every
    # session). Treat it like any other malformed value and restore the
    # default of 2. "Unlimited" is the same sentinel cek-login-ssh displays;
    # never rewrite it to 2 or enforce it.
    iplimit=$(cat "$file_path")
    if [ "$iplimit" = "Unlimited" ]; then
        rm -f "/var/lib/fn-autosc/limit-ip/ssh/${user}"
        continue
    fi
    if ! [[ "$iplimit" =~ ^[1-9][0-9]*$ ]]; then
        iplimit=2
        echo "$iplimit" > "$file_path"
        rm -f "/var/lib/fn-autosc/limit-ip/ssh/${user}"
    fi

    # Found 512: an account already locked by passwd -l keeps its original
    # 15-minute auto-unlock due.  Re-locking every 5 minutes would reset the
    # timer and spam the operator while the old sessions are still connected.
    # Found 515: drop any stale two-sample state as well; otherwise a manual
    # unlock would re-lock on the first over-limit tick without a new grace.
    if passwd -S "$user" 2>/dev/null | grep -q " L "; then
        rm -f "/var/lib/fn-autosc/limit-ip/ssh/${user}"
        continue
    fi

    _curips=$(awk -F'\t' -v u="$user" '$1==u {print $2}' "$SSH_ONLINE" | sort -u)
    cekcek=$(printf '%s\n' "$_curips" | sed '/^$/d' | wc -l)

    # Mendapatkan daftar IP untuk pengguna (unique active client IPs)
    ip_list=$(awk -F'\t' -v u="$user" '$1==u {print $2" - " $3}' "$SSH_ONLINE" | sort -u)

    # Found 512: CGNAT handover can make one device look like N IPs for a few
    # seconds.  Like the Xray limiters (Found 509), lock only when the SAME
    # over-limit IP set is seen on two consecutive 5-minute runs (>=240s).
    _state="/var/lib/fn-autosc/limit-ip/ssh/${user}"
    if [[ $user != "root" && $cekcek -gt $iplimit ]]; then
        _prev_epoch=""
        _prev_ips=""
        if [ -f "$_state" ]; then
            _prev_epoch=$(sed -n '1p' "$_state" 2>/dev/null)
            _prev_ips=$(sed -n '2,$p' "$_state" 2>/dev/null)
        fi
        if [ "$_curips" = "$_prev_ips" ] && [[ "$_prev_epoch" =~ ^[0-9]+$ ]]; then
            if [ $(( $(date +%s) - _prev_epoch )) -ge 240 ]; then
                rm -f "$_state"
            else
                # Same set, not old enough: keep the original epoch.  A
                # frequent manual run must not keep resetting the grace.
                echo "$user: $cekcek IPs (> $iplimit), waiting for a stable second sample"
                continue
            fi
        else
            mkdir -p "$(dirname "$_state")"
            { echo "$(date +%s)"; printf '%s\n' "$_curips"; } > "$_state"
            echo "$user: $cekcek IPs (> $iplimit), waiting for a stable second sample"
            continue
        fi
    else
        rm -f "$_state"
    fi

    # Pastikan user root tidak dikunci
    if [[ $user != "root" && $cekcek -gt $iplimit ]]; then
        if ! passwd -l "$user" >/dev/null 2>&1; then
            echo "limit-ip-ssh: failed to lock $user; will retry" >&2
            continue
        fi
        echo "$user dikunci karena melebihi batas login."
        unlock_time=$(date -d "15 minutes" "+%Y-%m-%d %H:%M:%S")
        mkdir -p /etc/xray/autounlock/ssh
        echo $(( $(date +%s) + 900 )) > /etc/xray/autounlock/ssh/$user
        ssh_kick_user "$user"
        logs >/dev/null 2>&1
        nais=3
    else
        echo > /dev/null
    fi
    sleep 0.1
done

# Drop per-user IP-evidence state for accounts that no longer exist.
for _st in /var/lib/fn-autosc/limit-ip/ssh/*; do
    [ -e "$_st" ] || continue
    _su=$(basename "$_st")
    if ! printf '%s\n' "$username" | grep -qxF -- "$_su"; then
        rm -f "$_st"
    fi
done

# Found 515: passwd -l takes effect on the next authentication; restarting
# ssh/sshd/ws here is unnecessary and drops every other SSH/WS session when
# one account is locked.  The auto-unlock sweeper is independent of
# ssh-online and keeps its due file until passwd -u succeeds.
ssh_auto_unlock
if [[ $nais -gt 1 ]]; then
    clear
    echo ""
    echo ""
else
    echo > /dev/null
fi

# Membersihkan file sementara setelah pemrosesan
rm -f /tmp/login-db.txt /tmp/login-ssh.txt /tmp/vpn-login-tcp.txt /tmp/vpn-login-udp.txt
