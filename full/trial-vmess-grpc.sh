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
    echo ""
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
echo ""
domain=$(cat /etc/xray/domain)
# Alternate domain, rotated for balance (no default; list order only)
rdomains=("$domain")
if [ -s /etc/xray/domains ]; then
    _seen="|$domain|"
    while IFS= read -r _d || [ -n "$_d" ]; do
        _d=$(echo "$_d" | tr -d '[:space:]')
        if [ -n "$_d" ] && [[ "$_seen" != *"|$_d|"* ]]; then
            rdomains+=("$_d")
            _seen="$_seen$_d|"
        fi
    done < /etc/xray/domains
fi
dseq=$(cat /etc/xray/.domainseq 2>/dev/null || echo 0)
rdomain="${rdomains[$((dseq % ${#rdomains[@]}))]}"
echo $((dseq+1)) > /etc/xray/.domainseq
alldom=$(printf '%s,' "${rdomains[@]}" | sed 's/,$//; s/,/, /g')
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
isp=$(cat /root/.isp 2>/dev/null)
region=$(cat /root/.region 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
clear
echo ""
echo ""
echo ""
user=trial`</dev/urandom tr -dc 0-9 | head -c3`
masaaktif="1"
quota="1"
ip="1"
# Limit Quota
if [[ $quota -gt 0 ]]; then
echo -e "$(($quota * 1024 * 1024 * 1024))" > /etc/xray/quota/grpc/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/grpc/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%d-%b-%Y"`

# Generate UUID
uuid=$(xray uuid)

# Menambahkan akun pada json
sed -i '/#vmess$/{n;s/}/},\n### '"$user $exp"'\n{"id": "'""$uuid""'","alterid": 0,"email": "'""$user""'","level": 0}/}' /etc/xray/json/grpc.json
# vmgr stays the default and keeps working, but links never use it; rotation below is color-based only.
opaths=("black" "gray" "silver")
cseq=$(cat /etc/xray/.colorseq 2>/dev/null || echo 0)
opath="${opaths[$((cseq % ${#opaths[@]}))]}"
echo $((cseq+1)) > /etc/xray/.colorseq

# Me Restart Service
if xray run -test -config /etc/xray/json/grpc.json >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl restart xray@grpc
    systemctl restart quota-grpc
fi

# Konfigurasi Json gRPC
grpc=`cat<<eof
{
"v": "2",
"ps": "${user}",
"add": "${rdomain}",
"port": "443",
"id": "${uuid}",
"aid": "0",
"net": "grpc",
"path": "$opath",
"type": "none",
"host": "${rdomain}",
"tls": "tls"
}
eof`

# Membuat Menjadi Link Untuk Client
vmesslink1="vmess://$(echo $grpc | base64 -w 0)"

clear
echo ""
echo ""
echo ""
TEKS="
-----------------------
🟢 XRAY VMESS GRPC 🟢
-----------------------

Remarks : $user
Domain  : ${rdomain}
Domains : $alldom
ISP     : $isp
Region  : $region
UUID    : $uuid
Expired : $exp
Protokol: Vmess
-----------------------
Limit Detail

Limit IP: $ip
Quota   : $quota GB
-----------------------
Detail Port

Port        : 443, 2053, 2083, 2087, 2096
-----------------------
AlterID     : 0
Service     : vmgr
Service Alt : black / gray / silver
Network     : gRPC
Alpn        : - [ None ]
Decrypt     : auto
-----------------------
🔵 VMess GRPC

$vmesslink1
-----------------------
"
if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
    curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "disable_web_page_preview=1" --data-urlencode "parse_mode=html" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/&/\&amp;/g' -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g' -e 's|^\(vmess://[^ ]*\)$|<code>\1</code>|' -e 's|^\(vless://[^ ]*\)$|<code>\1</code>|' -e 's|^\(trojan://[^ ]*\)$|<code>\1</code>|' -e 's|^\([A-Za-z][^:]*: \)\(.*\)$|<code>\1\2</code>|')" $URL >/dev/null 2>&1
fi
echo -e "$TEKS" > /var/log/create/xray/grpc/${user}.log
echo 'sed -i "/^### '"$user"' '"$exp"'/ {N;d}" /etc/xray/json/grpc.json && sed -i -z '"'"'s/},\n *\]/}\n        ]/g'"'"' /etc/xray/json/grpc.json && systemctl restart xray@grpc && systemctl restart quota-grpc && rm -fr /var/log/create/xray/grpc/'"$user"'.log && rm -fr /etc/xray/limit/ip/xray/grpc/'"$user"' && rm -fr /etc/xray/quota/grpc/'"$user"' /etc/xray/quota/grpc/'"$user"'_usage' | at now + 60 minutes >/dev/null 2>&1
clear
echo ""
echo ""
echo ""
source /etc/funny/format.sh
format_display "$TEKS"
