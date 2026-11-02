#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


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
<b>ACCOUNT UNLOCKED</b>
<b>-----------------------</b>
<code>Date     : $DATE</code>
<code>Username : $name</code>
<code>Expired  : $exp2</code>
<code>Protocol : $protokol2</code>
<code>Transport: HU</code>
<b>-----------------------</b>
<i>Catatan:</i> The user account has been unlocked by the owner and can be used again."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Menampilkan daftar akun terkunci
# Menampilkan daftar akun terkunci untuk di-unlock
locked_files=$(ls /var/log/create/xray/http/*.locked 2>/dev/null)

if [ -n "$locked_files" ]; then
    clear
    echo ""
    echo ""
    echo -e "${NC}${separator}
       UNLOCK XRAY HTTP ACCOUNT
${separator}"

    count=0
    names=()
    for file in $locked_files; do
        username=$(basename "$file" .locked)
        uid=$(grep "UUID" "$file" | awk '{print $3}')
        exp=$(grep "Expired" "$file" | awk '{print $3}')
        protokol=$(grep -E "^(Protokol|Protocol) *:" "$file" | awk '{print $NF}')
        protokol=${protokol^^}
        count=$((count+1))
        names+=("$username")

        echo -e "${green}$(printf '%02d' $count)${NC}. Username : ${green}$username${NC}"
        echo -e "    Status   : ${red}Locked${NC}"
        echo -e "    UUID     : $uid"
        echo -e "    Expired  : $exp"
        echo -e "    Protocol : $protokol"
        echo -e "${blue_sep}"
    done
    echo -e "${orange}Press [Ctrl + C] to exit${NC}"
    echo -e "${separator}"

    read -p "Input Username or number to Unlock: " _input || exit 0
    name="$_input"
    if [[ "$_input" =~ ^[0-9]+$ ]]; then
        _n=$((10#$_input))
        if [ "$_n" -ge 1 ] && [ "$_n" -le "${#names[@]}" ]; then
            name="${names[$((_n-1))]}"
        fi
    fi
    [ -z "$name" ] && exit 0
    if [ ! -f "/var/log/create/xray/http/${name}.locked" ]; then
        echo "User '$name' has no locked account file."
        exit 1
    fi
else
    clear
    echo ""
    echo ""
    echo "No locked accounts found to unlock."
    exit 1
fi

# Menampilkan detail akun yang akan di-unlock
uuid=$(grep "UUID" /var/log/create/xray/http/${name}.locked | awk '{print $3}')
exp2=$(grep "Expired" /var/log/create/xray/http/${name}.locked | awk '{print $3}')
protokol2=$(grep -E "^(Protokol|Protocol) *:" /var/log/create/xray/http/${name}.locked | awk '{print $NF}')
protokol2=${protokol2^^}

clear
echo ""
echo ""
echo -e "${NC}${separator}
       UNLOCK ACCOUNT DETAILS
${separator}
Date     : $(date)
Username : ${green}$name${NC}
Expired  : $exp2
UUID     : $uuid
Protocol : $protokol2
Status   : ${green}Unlocked${NC}
${separator}"

# Already present (restored by hand or a previous run):
# never append a second copy - it would invalidate the JSON.
if [ -n "$exp2" ] && grep -qxF "### $name $exp2" /etc/xray/json/upgrade.json 2>/dev/null; then
    echo "Account '$name' already present in config - skipping re-add."
elif [ "$protokol2" == "VMESS" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/upgrade.json vmess "$name" "$exp2" "$uuid" || { echo "unlock-http: failed to insert $name into the JSON config." >&2; exit 1; }
elif [ "$protokol2" == "VLESS" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/upgrade.json vless "$name" "$exp2" "$uuid" || { echo "unlock-http: failed to insert $name into the JSON config." >&2; exit 1; }
elif [ "$protokol2" == "TROJAN" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/upgrade.json trojan "$name" "$exp2" "$uuid" || { echo "unlock-http: failed to insert $name into the JSON config." >&2; exit 1; }
else
    echo "Protokol tidak dikenal"
fi

# Found 497 guard (same class as unlock-*-auto): the re-add above is a
# silent no-op when the JSON client insertion fails. Never move .locked
# to .log without a JSON entry - auto-delete-* would wipe the account
# ("Log Cleanup") instead of unlocking it. Fail LOUD, keep the lock.
if ! grep -qxF "### $name $exp2" /etc/xray/json/upgrade.json 2>/dev/null; then
    echo "unlock-http: FAILED to restore $name - JSON client insertion failed, lock kept. Check the JSON config, then retry." >&2
    exit 1
fi
if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then
    mv /var/log/create/xray/http/${name}.locked /var/log/create/xray/http/${name}.log
    systemctl daemon-reload
    systemctl restart xray@upgrade
    # Send Notif Telegram
    send_log
fi

