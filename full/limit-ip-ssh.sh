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

# Membaca File Log
LOG=""
if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
else
    echo "Log file not found!"
    exit 1
fi

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
echo " "
echo " "

# Dropbear
echo "----------=[ Dropbear User Login ]=-----------"
echo "ID  |  Username  |  IP Address  |  Time"
echo "----------------------------------------------"
# Bug 70/71: dropbear (the daemon serving SSH accounts on port 109) starts with
# -E and logs only to the systemd journal on Debian 12 - /var/log/auth.log
# contains zero dropbear lines - and rsyslog there writes RFC3339 timestamps
# the old fixed field offsets cannot parse. Pull both sources for the last 10
# minutes and parse the username/IP out of the message body, which is
# identical in every log format.
grep -E "Password auth succeeded" "$DB_LOG" > /tmp/login-db.txt

# Bug 70/71: extract fields from the message body (works for classic syslog and
# RFC3339 prefixes alike): "Password auth succeeded for 'user' from ip:port"
while IFS= read -r line; do
    [[ "$line" =~ \[([0-9]+)\] ]] && PID="${BASH_REMATCH[1]}" || PID="-"
    USER=$(sed -n "s/.*Password auth succeeded for '\([^']*\)' from.*/\1/p" <<< "$line")
    HOSTPORT=$(sed -n "s/.*Password auth succeeded for '[^']*' from \([^ ]*\).*/\1/p" <<< "$line")
    [ -n "$USER" ] || continue
    IP="${HOSTPORT%:*}"
    IP="${IP%\]}"
    TIME=$(awk '{ if ($1 ~ /^[A-Z][a-z][a-z]$/) print $1" "$2" "$3; else { ts=$1; sub(/\.[0-9]+\+/, "+", ts); print ts } }' <<< "$line")
    echo "$PID - $USER - $IP - $TIME"
done < /tmp/login-db.txt

echo " "
echo "----------=[ OpenSSH User Login ]=------------"
echo "ID  |  Username  |  IP Address  |  Time"
echo "----------------------------------------------"
# Bug 70/71: same for OpenSSH - parse from the message body so RFC3339 and
# classic syslog prefixes both work.
grep -E "Accepted password for" "$SSH_LOG" > /tmp/login-ssh.txt

# Bug 70/71: message-body parse - "Accepted password for user from ip port n"
while IFS= read -r line; do
    [[ "$line" =~ sshd\[([0-9]+)\] ]] && PID="${BASH_REMATCH[1]}" || PID="-"
    USER=$(sed -n "s/.*Accepted password for \([^ ]*\) from .*/\1/p" <<< "$line")
    IP=$(sed -n "s/.*Accepted password for [^ ]* from \([^ ]*\) port.*/\1/p" <<< "$line")
    [ -n "$USER" ] || continue
    TIME=$(awk '{ if ($1 ~ /^[A-Z][a-z][a-z]$/) print $1" "$2" "$3; else { ts=$1; sub(/\.[0-9]+\+/, "+", ts); print ts } }' <<< "$line")
    echo "$PID - $USER - $IP - $TIME"
done < /tmp/login-ssh.txt

# OpenVPN TCP Log
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
    echo ""
    echo "---------=[ OpenVPN TCP User Login ]=---------"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo "----------------------------------------------"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
    cat /tmp/vpn-login-tcp.txt
fi

# OpenVPN UDP Log
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
    echo " "
    echo "---------=[ OpenVPN UDP User Login ]=---------"
    echo "Username  |  IP Address  |  Connected  |  Time"
    echo "----------------------------------------------"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
    cat /tmp/vpn-login-udp.txt
fi
echo "----------------------------------------------"
echo ""
}

logs() {
    TEKS="
Log Multi Login SSH
=================
Username: $user
Limit IP: $iplimit
Total Login: $cekcek
Unlock Time: $unlock_time
=================
  [ Time Login ]
$ip_list
=================
The account will be locked for 15 minutes and will be unlocked automatically.
"
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL >/dev/null 2>&1
clear
}

clear
# Bug 64: field 3 of /etc/passwd is the UID, field 4 is the GID. The old
# pattern discarded the UID and enrolled every account whose GID >= 1000
# (system accounts such as sync/_apt/sshd) while exempting real users whose
# primary group is below 1000. Match the Go tools (uid >= 1000, uid < 65534).
username=$(while IFS=: read -r username _ uid _ _ _ _; do
    if [[ $uid -ge 1000 && $uid -lt 65534 && $username != "nobody" && $username != "root" ]]; then
        echo "$username"
    fi
done < /etc/passwd)
clear

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

# Regression fix R12: only count logins from the last 10 minutes. Removing the
# old auth.log truncation (Bug 19 / R7) made every historical login count
# forever, so a user who once exceeded the limit was re-locked every 5 minutes
# after each automatic unlock. The 10-minute window stays below the 15-minute
# unlock delay, so unlocked accounts stay unlocked unless they exceed the
# limit again with fresh logins.
#
# Bug 70/71 sources: dropbear login events only exist in the systemd journal on
# Debian 12 (the -E flag keeps them out of /var/log/auth.log), and OpenSSH
# events live in the auth log with either classic or RFC3339 timestamps.
recent_auth=$(mktemp)
DB_LOG=$(mktemp)
SSH_LOG=$(mktemp)
cut_ref=$(date -d '10 minutes ago' '+%Y %m %d %H %M %S')
now_ref=$(date '+%Y %m %d')
read -r cutY cutM cutD cutH cutMin cutS <<< "$cut_ref"
read -r nowY nowM nowD <<< "$now_ref"
awk -v cy="$nowY" -v cm="$nowM" -v cd="$nowD" \
    -v wy="$cutY" -v wm="$cutM" -v wd="$cutD" -v wh="$cutH" -v wmi="$cutMin" -v ws="$cutS" '
    BEGIN {
        split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", mons, " ")
        for (i = 1; i <= 12; i++) mon[mons[i]] = i
        cm += 0; cd += 0
        cut = ((((wy * 12 + wm) * 32 + wd) * 24 + wh) * 60 + wmi) * 60 + ws
    }
    # Bug 70/71: RFC3339 prefix, e.g. 2026-09-23T23:02:44.123456+08:00
    $1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/ {
        y = substr($1, 1, 4) + 0; mo = substr($1, 6, 2) + 0; d = substr($1, 9, 2) + 0
        hh = substr($1, 12, 2) + 0; mi = substr($1, 15, 2) + 0; s = substr($1, 18, 2) + 0
        k = ((((y * 12 + mo) * 32 + d) * 24 + hh) * 60 + mi) * 60 + s
        if (k >= cut) print
        next
    }
    # Classic syslog prefix: Sep 23 23:02:44 ...
    ($1 in mon) {
        if ($3 !~ /^[0-9]+:[0-9]+:[0-9]+$/) next
        split($3, t, ":")
        y = cy
        if (mon[$1] > cm || (mon[$1] == cm && ($2 + 0) > cd)) y = cy - 1
        k = ((((y * 12 + mon[$1]) * 32 + ($2 + 0)) * 24 + (t[1] + 0)) * 60 + (t[2] + 0)) * 60 + (t[3] + 0)
        if (k >= cut) print
    }' "$LOG" > "$recent_auth"

# OpenSSH events: the system auth log always has them (rsyslog on Debian,
# /var/log/secure on CentOS); the message-body parser handles both formats.
grep -E "Accepted password for" "$recent_auth" > "$SSH_LOG"

# Dropbear events: prefer the systemd journal (native 10-minute window).
# Fall back to the auth log when journalctl is unavailable or has never seen
# the dropbear unit.
if command -v journalctl >/dev/null 2>&1 && journalctl -u dropbear -n 20 --no-pager 2>/dev/null | grep -q .; then
    journalctl -u dropbear --since "-10 minutes" --no-pager 2>/dev/null | grep -E "Password auth succeeded" > "$DB_LOG"
else
    grep -E "Password auth succeeded" "$recent_auth" > "$DB_LOG"
fi

mulog=$(mesinssh)
rm -f "$recent_auth" "$DB_LOG" "$SSH_LOG"
date=$(date)

for user in $username
do
    file_path="/etc/xray/limit/ip/ssh/$user"
    if [ ! -f "$file_path" ]; then
        echo "2" > "$file_path"
        echo "File untuk pengguna $user dibuat dan diisi dengan 2."
    fi

    # Bug 64: match the exact username field (" - user - ") so a short name
    # (or a numeric name inside an IP address) never counts other logins.
    # Non-numeric limits (bad manual edit) fall back to the default of 2.
    iplimit=$(cat "$file_path")
    if ! [[ "$iplimit" =~ ^[0-9]+$ ]]; then
        iplimit=2
        echo "$iplimit" > "$file_path"
    fi
    cekcek=$(echo -e "$mulog" | grep -F " - $user - " | wc -l)

    # Mendapatkan daftar IP untuk pengguna
    # Bug 75: the log line format is "PID - USER - IP - TIME", so the IP is
    # always field 5. $NF returned a fragment of the timestamp instead.
    ip_list=$(echo -e "$mulog" | grep -F " - $user - " | awk '{print $5}' | sort | uniq | tr '\n' ', ' | sed 's/, $//')

    # Pastikan user root tidak dikunci
    if [[ $user != "root" && $cekcek -gt $iplimit ]]; then
        systemctl daemon-reload
        systemctl restart ssh
        systemctl restart sshd
        systemctl restart ws
        passwd -l "$user"
        echo "$user dikunci karena melebihi batas login."
        unlock_time=$(date -d "15 minutes" "+%Y-%m-%d %H:%M:%S")
        echo "passwd -u $user" | at now + 15 minutes
        logs >/dev/null 2>&1
        nais=3
    else
        echo > /dev/null
    fi
    sleep 0.1
done

if [[ $nais -gt 1 ]]; then
    clear
else
    echo > /dev/null
fi

# Membersihkan log SSH setelah pemrosesan
echo "" > /tmp/login-db.txt
echo "" > /tmp/login-ssh.txt
echo "" > /tmp/vpn-login-tcp.txt
echo "" > /tmp/vpn-login-udp.txt
# echo "" > /var/log/auth.log
# Membersihkan log asli dari file $LOG
# echo "" > ${LOG}