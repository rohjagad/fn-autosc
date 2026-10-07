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
until [[ $user =~ ^[a-z0-9_]+$ && ${client_exists} == '0' && ! -f /var/log/create/xray/xhttp/${user}.log ]]; do
    echo -e "
[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-\033[0m
        \033[1;33mCreate Trojan XHTTP\033[0m
[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-\033[0m
"
    read -p "Username: " user || exit 0
    if [[ -z "$user" ]]; then
        clear
        echo ""
        echo ""
        echo -e "\033[0;31mUsername cannot be empty.\033[0m"
        continue
    fi

    if [[ $user =~ [A-Z] || $user =~ [[:space:]] ]]; then
        clear
        echo ""
        echo ""
        echo -e "\033[0;31mUsername cannot contain uppercase letters or spaces.\033[0m"
        continue
    fi

    if [[ $user =~ [^a-z0-9_] ]]; then
        clear
        echo ""
        echo ""
        echo -e "Username can only contain lowercase letters, numbers, and underscores."
        continue
    fi

    client_exists=$(grep -w "$user" /etc/xray/json/xhttp.json | wc -l)

    if [[ ${client_exists} -gt 0 ]]; then
        clear
        echo ""
        echo ""
        echo -e "\033[0;31mUsername already exists.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/xhttp/${user}.log ]]; then
        clear
        echo ""
        echo ""
        echo -e "\033[0;31mUsername already exists in log file.\033[0m"
        continue
    fi

    if [[ -f /var/log/create/xray/xhttp/${user}.locked ]]; then
        clear
        echo ""
        echo ""
        echo -e "\033[0;31mUsername already exists in locked file.\033[0m"
        continue
    fi
done
    echo ""
    echo -e "\033[38;5;208m0 not allowed\033[0m"
    read -p "Limit Ip: " ip
    while ! [[ "$ip" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Limit Ip: " ip || exit 1
    done
    read -p "Limit Quota (GBs): " quota
    while ! [[ "$quota" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Limit Quota (GBs): " quota || exit 1
    done
    read -p "Active Time (days): " masaaktif
    while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Active Time (days): " masaaktif || exit 1
    done
    read -p "Input UUID (Empty Default): " uuid

# Validasi UUID
if [[ -z "$uuid" ]] || ! [[ "$uuid" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "UUID empty or has unsafe characters, generating new UUID..."
    uuid=$(xray uuid)
    echo "New UUID: $uuid"
else
    echo "Using provided UUID: $uuid"
fi

# Limit Quota
if [[ $quota -gt 0 ]]; then
echo -e "$(($quota * 1024 * 1024 * 1024))" > /etc/xray/quota/xhttp/$user
else
echo > /dev/null
fi

# Limit IP
if [[ $ip -gt 0 ]]; then
echo -e "${ip}" > /etc/xray/limit/ip/xray/xhttp/$user
else
echo > /dev/null
fi

# Masa Aktif
exp=`date -d "$masaaktif days" +"%d-%b-%Y"`

# Menambahkan Akun di Database
sed -i '/#trojan$/{n;s/}/},\n### '"$user $exp"'\n{"password": "'""$uuid""'","email": "'""$user""'","level": 0}/}' /etc/xray/json/xhttp.json
# /trxh stays the default and keeps working, but links never use it; rotation below is color-based only.
opaths=("/brown" "/tan" "/beige")
cseq=$(cat /etc/xray/.colorseq 2>/dev/null || echo 0)
opath="${opaths[$((cseq % ${#opaths[@]}))]}"
echo $((cseq+1)) > /etc/xray/.colorseq

# Restart Service
if xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl restart xray@xhttp
    systemctl restart quota-xhttp
fi

# Konfigurasi Trojan xhttp TLS
link1="trojan://${uuid}@${rdomain}:443?path=$opath&security=tls&host=${rdomain}&type=xhttp&sni=${rdomain}#${user}"

# Konfigurasi Trojan xhttp NonTLS
link2="trojan://${uuid}@${rdomain}:80?path=$opath&security=none&host=${rdomain}&type=xhttp#${user}"

TEKS="
-----------------------
🟢 ACCOUNT DETAIL 🟢
-----------------------

Remarks  : $user
Domains  : $alldom
ISP      : $isp
Region   : $region
UUID     : $uuid
Expired  : $exp
Protocol : TROJAN
Transport: XHTTP
-----------------------
Limit Detail

Limit IP: $ip
Quota   : $quota GB
-----------------------
Detail Port

Port TLS : 443, 2053, 2083, 2087, 2096
Port None: 80, 8880, 2052, 2082, 2095
-----------------------
Path     : /trxh
Path Alt : /brown /tan /beige
Network  : XHTTP
-----------------------
🔵 Trojan XHTTP TLS

$link1
-----------------------
🔵 Trojan XHTTP none

$link2
-----------------------
"
if [ -n "$CHATID" ] && [ -n "$KEY" ]; then
    curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "disable_web_page_preview=1" --data-urlencode "parse_mode=html" --data-urlencode "text=$(printf '%s' "$TEKS" | sed -e '/^Domain   : /d' -e 's/&/\&amp;/g' -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g' -e 's|^\(vmess://[^ ]*\)$|<code>\1</code>|' -e 's|^\(vless://[^ ]*\)$|<code>\1</code>|' -e 's|^\(trojan://[^ ]*\)$|<code>\1</code>|' -e 's|^\([A-Za-z][^:]*: \)\(.*\)$|<code>\1\2</code>|')" $URL >/dev/null 2>&1
fi
echo -e "$TEKS" > /var/log/create/xray/xhttp/${user}.log
clear
echo ""
echo ""
source /etc/funny/format.sh
format_display "$TEKS"
