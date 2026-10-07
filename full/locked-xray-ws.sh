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
# Colors
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
red='\033[0;31m'
NC='\033[0m'

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
<b>ACCOUNT LOCKED</b>
<b>-----------------------</b>
<code>Date     : $DATE</code>
<code>Username : $name</code>
<code>Expired  : $exp2</code>
<code>Protocol : $protokol2</code>
<code>Transport: WS</code>
<b>-----------------------</b>
<i>Catatan:</i> The user account has been locked by the owner and cannot be used."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
# Menampilkan daftar akun aktif untuk di-lock
locked_files=$(ls /var/log/create/xray/ws/*.log 2>/dev/null)

if [ -n "$locked_files" ]; then
    clear
    echo ""
    echo ""
    echo -e "${NC}${separator}
        LOCK XRAY WS ACCOUNT
${separator}"

    count=0
    names=()
    for file in $locked_files; do
        username=$(basename "$file" .log)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep -E "^(Protokol|Protocol) *:" "$file" | awk '{print $NF}')
        protokol=${protokol^^}
        count=$((count+1))
        names+=("$username")

        echo -e "${green}$(printf '%02d' $count)${NC}. Username : ${green}$username${NC}"
        echo -e "    Status   : ${green}Active${NC}"
        echo -e "    UUID     : $uid"
        echo -e "    Expired  : $exp"
        echo -e "    Protocol : $protokol"
        echo -e "${blue_sep}"
    done
    echo -e "${orange}Press [Ctrl + C] to exit${NC}"
    echo -e "${separator}"

    read -p "Input Username or number to Lock: " _input || exit 0
    name="$_input"
    if [[ "$_input" =~ ^[0-9]+$ ]]; then
        _n=$((10#$_input))
        if [ "$_n" -ge 1 ] && [ "$_n" -le "${#names[@]}" ]; then
            name="${names[$((_n-1))]}"
        fi
    fi
    [ -z "$name" ] && exit 0
else
    clear
    echo ""
    echo ""
    echo "No active accounts found to lock."
    exit 1
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/ws/${name}.log | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/ws/${name}.log | awk '{print $3}')
protokol2=$(grep -E "^(Protokol|Protocol) *:" /var/log/create/xray/ws/${name}.log | awk '{print $NF}')
protokol2=${protokol2^^}

clear
echo ""
echo ""
echo -e "${NC}${separator}
        LOCK ACCOUNT DETAILS
${separator}
Date     : $(date)
Username : ${green}$name${NC}
Expired  : $exp2
UUID     : $uuid
Protocol : $protokol2
Status   : ${red}Locked${NC}
${separator}"

    exp=$(grep -wE "^### $name" "/etc/xray/json/ws.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
    sed -i "/^### $name $exp/ {N;d}" /etc/xray/json/ws.json
    sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
    if xray run -test -config /etc/xray/json/ws.json >/dev/null 2>&1; then
        mv /var/log/create/xray/ws/${name}.log /var/log/create/xray/ws/${name}.locked
        systemctl daemon-reload
        systemctl restart xray@ws
        # Send Notif Telegram
        send_log
    fi
