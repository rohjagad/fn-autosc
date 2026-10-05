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

# Function Bytes Quota
function bytes() {
    local -i bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( (bytes + 1023) / 1024 )) KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( (bytes + 1048575) / 1048576 )) MB"
    elif [[ $bytes -lt 1099511627776 ]]; then
        echo "$(( (bytes + 1073741823) / 1073741824 )) GB"
    elif [[ $bytes -lt 1125899906842624 ]]; then
        echo "$(( (bytes + 1099511627775) / 1099511627776 )) TB"
    elif [[ $bytes -lt 1152921504606846976 ]]; then
        echo "$(( (bytes + 1125899906842623) / 1125899906842624 )) PB"
    else
        echo "$(( (bytes + 1152921504606846975) / 1152921504606846976 )) EB"
    fi
}

clear
RSEP='[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-[0m'
echo -e "$RSEP"
echo -e "    XTLS WEBSOCKET ACCOUNT LIST"
echo -e "$RSEP"
> /var/log/xray/accsess.log

# Numbered user list, like Check Database Logs (option 10)
data=( $(ls /var/log/create/xray/ws/ | sed -E 's/\.(locked|log)$//' | sort -u) )

if [ ${#data[@]} -eq 0 ]; then
    echo -e "No active accounts found."
    echo -e "$RSEP"
    exit 0
fi

i=1
for u in "${data[@]}"; do
    printf "\e[32;1m%02d\e[0m. %s\n" "$i" "$u"
    i=$((i+1))
done
echo -e "\033[1;34m-----------------------------------\033[0m"
echo -e "Total Accounts: ${#data[@]}"
echo -e "\033[1;34m-----------------------------------\033[0m"
echo -e "\033[38;5;208mPress [Ctrl + C] to exit\033[0m"
echo -e "$RSEP"
read -p "Input Username: " input || exit 0

# A number picks from the list, a name is used as-is
user="$input"
if [[ "$input" =~ ^[0-9]+$ ]]; then
    n=$((10#$input))
    if [ "$n" -ge 1 ] && [ "$n" -le "${#data[@]}" ]; then
        user="${data[$((n-1))]}"
    fi
fi

if [[ -f /var/log/create/xray/ws/${user}.locked ]]; then
    status="locked"
elif [[ -f /var/log/create/xray/ws/${user}.log ]]; then
    status="unlocked"
else
    echo -e "\e[31;1mUser not found: $input\e[0m"
    exit 0
fi

if [[ "$status" == "locked" ]]; then
    echo -e "\e[33;1mUser\e[32;1m: $user"
    echo -e "\e[33;1mStatus Account X-Ray\e[32;1m: $status"
    echo -e "$RSEP"
fi

if [[ "$status" == "unlocked" ]]; then
    limip=$(grep "Limit IP:" /var/log/create/xray/ws/${user}.log | awk '{print $3}')
    top=$(cat /etc/xray/quota/ws/$user 2>/dev/null || echo 0)
    quota=$(bytes "$top")
    uid=$(grep -F "\"email\": \"${user}\"" /etc/xray/json/ws.json | sed -nE 's/.*"(id|password)": "([^"]+)".*/\2/p' | sort -u | head -1)
    protokol=$(grep "Protokol:" /var/log/create/xray/ws/${user}.log | awk '{print $2}')
    exp=$(grep "Expired" /var/log/create/xray/ws/${user}.log | awk '{print $3}')
    echo -e "\e[33;1mUser\e[32;1m: $user"
    echo -e "\e[33;1mExpired\e[32;1m: $exp"
    echo -e "\e[33;1mLimit IP\e[32;1m: $limip"
    echo -e "\e[33;1mLimit Quota\e[32;1m: $quota"
    echo -e "\e[33;1mUUID / Password\e[32;1m: $uid"
    echo -e "\e[33;1mProtocol Account\e[32;1m: $protokol"
    echo -e "\e[33;1mStatus Account X-Ray\e[32;1m: $status"
    echo -e "$RSEP"
fi
