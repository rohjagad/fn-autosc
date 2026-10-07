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
NC='\e[0m'
GB='\e[32;1m'
YB='\e[33;1m'
blue='\033[1;34m'

rainbow_sep() {
  local text="${1:------------------------------------}"
  local output=''
  local i segment fraction r g b color
  local -a red=(255 255 0 0 0 255 255)
  local -a green=(0 255 255 255 0 0 0)
  local -a blue=(0 0 0 255 255 255 0)
  for ((i = 0; i < ${#text}; i++)); do
    if ((i == ${#text} - 1)); then
      segment=5
      fraction=$((${#text} - 1))
    else
      segment=$((i * 6 / (${#text} - 1)))
      fraction=$((i * 6 % (${#text} - 1)))
    fi
    r=$((red[segment] + (red[segment + 1] - red[segment]) * fraction / (${#text} - 1)))
    g=$((green[segment] + (green[segment + 1] - green[segment]) * fraction / (${#text} - 1)))
    b=$((blue[segment] + (blue[segment + 1] - blue[segment]) * fraction / (${#text} - 1)))
    printf -v color '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
    output+="${color}${text:i:1}"
  done
  printf '%b\n' "${output}${NC}"
}

separator=$(rainbow_sep '-----------------------------------')
blue_sep="${blue}-----------------------------------${NC}"

send_log() {
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    TIME="10"
    DATE=$(date +"%d-%b-%Y %H:%M:%S")

    TEXT="
<b>-----------------------</b>
<b>EXTEND EXPIRATION</b>
<b>-----------------------</b>
<code>Date         : $DATE</code>
<code>Username     : $user</code>
<code>Protocol     : $proto</code>
<code>Transport    : XHTTP</code>
<code>Old Expired  : $exp</code>
<code>New Expired  : $exp4</code>
<code>Status Quota : $quota_status</code>
<b>-----------------------</b>
<i>Note:</i> The account's active period has been extended. Modification has been reflected in the database."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

clear
echo ""
echo ""
echo ""
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/xray/json/xhttp.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    echo -e "${separator}"
    echo -e "         ${GB}XTLS XRAY XHTTP${NC}         "
    echo -e "${separator}"
    echo -e "  ${YB}You have no existing clients!${NC}"
    echo -e "${separator}"
    echo ""
    read -n 1 -s -r -p "Press any key to back on menu"
    x-xhttp
fi

clear
echo ""
echo ""
echo ""
echo -e "${separator}"
echo -e "         ${GB}XTLS XRAY XHTTP${NC}         "
echo -e "${separator}"
echo -e " ${YB}User  Expired${NC}  "
echo -e "${blue_sep}"
    _users=( $(grep -E "^### " "/etc/xray/json/xhttp.json" | awk '{print $2}' | sort -u) )
    _i=1
    for _u in "${_users[@]}"; do
        _e=$(grep -wE "^### $_u" "/etc/xray/json/xhttp.json" | cut -d ' ' -f 3 | sort -u | tr '\n' ' ')
        printf "\e[32;1m%02d\e[0m. %-20s %s\n" "$_i" "$_u" "$_e"
        _i=$((_i+1))
    done
echo ""
echo -e "${YB}Tap enter to go back${NC}"
echo -e "${separator}"
read -rp "Input Username or number: " _input || { clear; return 0; }
    user="$_input"
    if [[ "$_input" =~ ^[0-9]+$ ]]; then
        _n=$((10#$_input))
        if [ "$_n" -ge 1 ] && [ "$_n" -le "${#_users[@]}" ]; then
            user="${_users[$((_n-1))]}"
        fi
    fi
if [ -z "$user" ]; then
    x-xhttp
else
    echo ""
    echo -e "\033[38;5;208m0 not allowed\033[0m"
    read -p "Expired (days): " masaaktif
    while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
        echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
        read -p "Expired (days): " masaaktif || exit 1
    done
    exp=$(grep -wE "^### $user" "/etc/xray/json/xhttp.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
    proto=$(grep -E "^(Protokol|Protocol) *:" "/var/log/create/xray/xhttp/${user}.log" | awk '{print $NF}'); proto=${proto^^}
    now=$(date +%y-%m-%d) # internal epoch math only
    d1=$(date -d "$exp" +%s 2>/dev/null)
    if [ -z "$d1" ]; then
        echo -e "\033[0;31mUnparseable expiry for this account - leaving it unchanged.\033[0m"
        sleep 2
        x-xhttp
        return
    fi
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    exp3=$(($exp2 + $masaaktif))
    exp4=$(date -d "$exp3 days" +"%d-%b-%Y") # Expiry display: DD-Mon-YYYY
    sed -i "/^### $user /c\### $user $exp4" /etc/xray/json/xhttp.json
    sed -i "s/Expired : $exp/Expired  : $exp4/; s/Expired  : $exp/Expired  : $exp4/" /var/log/create/xray/xhttp/${user}.log

    echo -e "\n${YB}Reset total usage quota? (y/n):${NC}"
    read -rp "Input: " reset_quota
    if [[ $reset_quota == "y" || $reset_quota == "Y" ]]; then
        > /etc/xray/quota/xhttp/${user}_usage
        quota_status="Reset"
    else
        quota_status="No"
    fi

    if xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then systemctl restart xray@xhttp; fi
    send_log

    clear
    echo ""
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "         ${GB}XTLS XRAY XHTTP${NC}         "
    echo -e "${separator}"
    echo -e " ${YB}Client Name :${NC} $user"
    echo -e " ${YB}Type        :${NC} XHTTP"
    echo -e " ${YB}Protocol    :${NC} $proto"
    echo -e " ${YB}Expired On  :${NC} $exp4"
    echo -e " ${YB}Status Quota:${NC} $quota_status"
    echo -e "${separator}"
    echo ""
fi
