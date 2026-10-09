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
<b>CHANGE UUID</b>
<b>-----------------------</b>
<code>Date         : $DATE</code>
<code>Username     : $user</code>
<code>Protocol     : $proto</code>
<code>Transport    : HU</code>
<code>Old UUID     : $old</code>
<code>New UUID     : $new</code>
<b>-----------------------</b>
<i>Note:</i> The account UUID has been successfully changed. Modification has been reflected in the database."
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Colors for styling
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
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

# Fetch all usernames and UUIDs
usernames=($(grep "^### " /etc/xray/json/upgrade.json | awk '{print $2}' | sort | uniq))

# Clear screen and display header
clear
echo ""
echo ""
echo -e "${separator}"
echo -e "${GREEN}       Change UUID XRAY HTTP UPGRADE"
echo -e "${separator}"
echo -e "${blue_sep}"

# Display usernames
_i=1
for user in "${usernames[@]}"; do
    printf "${GREEN}%02d${NC}. %s\n" "$_i" "$user"
    _i=$((_i+1))
done

echo -e "${blue_sep}"
echo -e "${RED} Press CTRL + C to exit"
echo -e "${separator}"

# Prompt user input for username and validate
while true; do
    read -p "Input Username or number: " _input || { clear; return 0; }
    user="$_input"
    if [[ "$_input" =~ ^[0-9]+$ ]]; then
        _n=$((10#$_input))
        if [ "$_n" -ge 1 ] && [ "$_n" -le "${#usernames[@]}" ]; then
            user="${usernames[$((_n-1))]}"
        fi
    fi
    if [[ -z "$user" || ! -f "/var/log/create/xray/http/${user}.log" ]]; then
        echo -e "${RED}Invalid username! Please try again.${NC}"
    else
        break
    fi
done
    proto=$(grep -E "^(Protokol|Protocol) *:" "/var/log/create/xray/http/${user}.log" | awk '{print $NF}'); proto=${proto^^}

# Prompt for new UUID, generate if empty
# GET OLD UUID
old=$(grep -F "\"email\": \"${user}\"" /etc/xray/json/upgrade.json | sed -nE 's/.*"(id|password)": "([^"]+)".*/\2/p' | sort -u | head -1)
echo -e "Old UUID: $old"
read -p "New UUID (Enter for random): " new || { clear; return 0; }
if [[ -z "$new" ]]; then
    new=$(xray uuid)
    echo -e "Generated new UUID: $new"
    sleep 2
elif ! [[ "$new" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo -e "UUID has unsafe characters, generating new UUID..."
    new=$(xray uuid)
    echo -e "Generated new UUID: $new"
    sleep 2
fi
clear
echo ""
echo ""

# Replace old UUID with new UUID in necessary files
sed -i "s|\"id\": \"${old}\"|\"id\": \"${new}\"|" /etc/xray/json/*.json
sed -i "s|\"password\": \"${old}\"|\"password\": \"${new}\"|" /etc/xray/json/*.json
sed -i -E "s|^( *UUID[[:space:]]*:).*|\1 ${new}|" /var/log/create/xray/http/${user}.log
[ -n "$old" ] && sed -i "s|${old}|${new}|g" /var/log/create/xray/http/${user}.log

# The vmess share links in the card are base64 blobs that embed the UUID, so the
# plaintext replacement above cannot reach them. Rewrite those links as well, or
# the saved card keeps handing out the dead UUID.
if [ -n "$old" ] && command -v python3 >/dev/null 2>&1; then
python3 - "$old" "$new" "/var/log/create/xray/http/${user}.log" <<'PYEOF' 2>/dev/null || true
import base64, json, re, sys
old, new, path = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = open(path, encoding="utf-8", errors="surrogateescape").read()
except Exception:
    sys.exit(0)
def _fix(m):
    b = m.group(1)
    try:
        j = json.loads(base64.b64decode(b + "=" * (-len(b) % 4)))
    except Exception:
        return m.group(0)
    if isinstance(j, dict) and j.get("id") == old:
        j["id"] = new
    return "vmess://" + base64.b64encode(json.dumps(j, separators=(",", ":")).encode()).decode()
open(path, "w", encoding="utf-8", errors="surrogateescape").write(
    re.sub(r"vmess://([A-Za-z0-9+/=]+)", _fix, data))
PYEOF
fi

# Restart All Service
if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl restart xray@upgrade
fi

# Log Information
send_log

clear
echo ""
echo ""
# Confirmation message with updated information
echo -e "${separator}"
echo -e "${GREEN} UUID Update Successful!"
echo -e "${separator}"
echo -e "${YELLOW} Username      |       New UUID"
echo -e "${blue_sep}"
echo -e "${GREEN} $user      |       $new"
echo -e "${separator}"
