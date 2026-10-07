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
        echo "Your IP is not in the database"
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
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"; fi
    }

clear
echo ""
echo ""
echo ""
red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
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

acme() {
clear
echo ""
echo ""
echo ""
echo start
clear
echo ""
echo ""
echo ""
domain="${CHOSEN:-$(cat /etc/xray/domain)}"
clear
echo ""
echo ""
echo ""
echo "
L FN 项目更新证书
${separator}
Your Domain: $domain
${blue_sep}
4 For IPv4 &  For IPv6
"
echo -e "Generate new Ceritificate Please Input Type Your VPS"
read -p "Input Your Type Pointing ( 4 / 6 ): " ip_version
if [[ $ip_version == "4" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$domain" -keyout /etc/xray/xray.key -out /etc/xray/xray.crt 2>/dev/null
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    # haproxy not used in lite edition
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Cert installed for IPv4."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
elif [[ $ip_version == "6" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d $domain --force --standalone -k ec-256 --listen-v6 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d $domain --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$domain" -keyout /etc/xray/xray.key -out /etc/xray/xray.crt 2>/dev/null
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    # haproxy not used in lite edition
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Cert installed for IPv6."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    cert
fi
}






fn() {
clear
echo ""
echo ""
echo ""
echo start
domain="${CHOSEN:-$(cat /etc/xray/domain)}"
systemctl stop nginx
cd /root/
clear
echo ""
echo ""
echo ""
echo "Starting... Port 80 will be stopped during SSL certificate installation"
certbot certonly --standalone --preferred-challenges http --agree-tos --email "$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")" -d $domain 
if [[ -s /etc/letsencrypt/live/$domain/fullchain.pem && -s /etc/letsencrypt/live/$domain/privkey.pem ]]; then
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
else
    echo "certbot failed - keeping the existing certificate."
fi
cd /etc/xray
systemctl start nginx
systemctl restart noobzvpns 2>/dev/null || true
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}


dmsl() {
systemctl stop nginx
clear
echo ""
echo ""
echo ""
#detail nama perusahaan
country="ID"
state="Central Kalimantan"
locality="Kab. Kota Waringin Timur"
organization="FN AutoSC"
organizationalunit="99999"
commonname="${CHOSEN:-FN}"
email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")

# delete
rm -fr /etc/xray/xray.*
rm -f /etc/haproxy/funny.pem

# make a certificate
openssl genrsa -out /etc/xray/xray.key 2048
openssl req -new -x509 -key /etc/xray/xray.key -out /etc/xray/xray.crt -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem 2>/dev/null
chmod 644 /etc/xray/xray.crt 2>/dev/null
chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem 2>/dev/null
systemctl daemon-reload
# haproxy not used in lite edition
systemctl restart noobzvpns 2>/dev/null || true
service nginx restart
echo -e "Self-signed certificate generated successfully"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

domain_sync_nginx() {
    # Rebuild the 443 server_name from primary + extras, then reload.
    local primary names
    primary=$(cat /etc/xray/domain 2>/dev/null)
    names="$primary $(tr '\n' ' ' < /etc/xray/domains 2>/dev/null)"
    names=$(echo "$names" | tr -s ' ' | sed 's/^ //; s/ $//')
    [ -z "$names" ] && { echo "No domain configured."; return 1; }
    python3 - "$names" <<'PYEOF2'
import re, sys
names = sys.argv[1]
p = "/etc/nginx/nginx.conf"
s = open(p).read()
lines = s.splitlines()
li = next(i for i, l in enumerate(lines) if "listen 443" in l)
tgt = next(i for i in range(li, len(lines)) if re.match(r"^\s*server_name\s", lines[i]))
ind = lines[tgt][:len(lines[tgt]) - len(lines[tgt].lstrip())]
lines[tgt] = ind + "server_name " + names + ";"
open(p, "w").write("\n".join(lines) + "\n")
print("server_name synced: " + names)
PYEOF2
    nginx -t 2>&1 | tail -1 && systemctl reload nginx
}

gen_selfsigned_all() {
    # Self-signed covering primary + extras (auto on domain add).
    local primary all san seen d
    primary=$(cat /etc/xray/domain 2>/dev/null)
    all="$primary $(tr '\n' ' ' < /etc/xray/domains 2>/dev/null)"
    san=""
    seen=""
    for d in $all; do
        [ -z "$d" ] && continue
        case ",$seen," in
            *",$d,"*) continue ;;
        esac
        seen="$seen,$d"
        san="$san,DNS:$d"
    done
    san="${san#,}"
    [ -z "$san" ] && { echo "No domain configured."; return 1; }
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
        -subj "/CN=$primary" -addext "subjectAltName=$san" \
        -keyout /etc/xray/.xray-selfsigned.key.tmp -out /etc/xray/.xray-selfsigned.crt.tmp 2>/dev/null || { rm -f /etc/xray/.xray-selfsigned.key.tmp /etc/xray/.xray-selfsigned.crt.tmp; return 1; }
    mv -f /etc/xray/.xray-selfsigned.crt.tmp /etc/xray/xray.crt
    mv -f /etc/xray/.xray-selfsigned.key.tmp /etc/xray/xray.key
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/.funny.pem.tmp 2>/dev/null \
        && mv -f /etc/haproxy/.funny.pem.tmp /etc/haproxy/funny.pem 2>/dev/null
    chmod 600 /etc/haproxy/funny.pem 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
    # haproxy not used in lite edition
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Self-signed installed for: $(echo "$san" | sed 's/DNS://g; s/,/, /g')"
}


domain_extra_add() {
    clear
    echo ""
    echo ""
    echo ""
    local primary cur
    primary=$(cat /etc/xray/domain 2>/dev/null)
    cur=$(tr '\n' ' ' < /etc/xray/domains 2>/dev/null)
    echo -e "${separator}"
    echo -e "Add Extra Domain (rotation)"
    echo -e "${separator}"
    echo -e "Primary : $primary"
    echo -e "Extras  : ${cur:-<none>}"
    echo -e "${separator}"
    echo ""
    read -p "New extra domain: " nd || return
    if ! [[ "$nd" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Domain must be a valid DNS hostname."
        sleep 2
        return
    fi
    if [ "$nd" = "$primary" ] || grep -qxF "$nd" /etc/xray/domains 2>/dev/null; then
        echo "Domain already listed."
        sleep 2
        return
    fi
    echo "$nd" >> /etc/xray/domains
    domain_sync_nginx
    echo ""
    gen_selfsigned_all
    echo ""
    echo "Note: live certificate is now self-signed (covers all domains)."
    echo "Point DNS for $nd at this VPS IP; trusted certs via options 4/5."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
}

domain_extra_del() {
    clear
    echo ""
    echo ""
    echo ""
    if [ ! -s /etc/xray/domains ]; then
        echo "No extra domains."
        sleep 2
        return
    fi
    echo -e "${separator}"
    echo -e "Remove Extra Domain"
    echo -e "${separator}"
    local i=1
    while IFS= read -r _d; do
        [ -n "$_d" ] && { echo -e "${green}$i${NC}. $_d"; i=$((i+1)); }
    done < /etc/xray/domains
    echo -e "${separator}"
    echo ""
    read -p "Number to remove (0 cancels): " nn || return
    if ! [[ "$nn" =~ ^[0-9]+$ ]] || [ "$nn" -lt 1 ]; then
        return
    fi
    local target
    target=$(grep -v '^\s*$' /etc/xray/domains | sed -n "${nn}p")
    [ -z "$target" ] && return
    grep -vxF "$target" /etc/xray/domains > /etc/xray/domains.tmp || true
    mv /etc/xray/domains.tmp /etc/xray/domains
    domain_sync_nginx
    echo "Removed $target."
    sleep 1
}


pick_domain() {
    # Choose a domain first (primary + extras, no default). Sets CHOSEN.
    unset CHOSEN
    local _all _d
    _all=()
    _all+=("$(cat /etc/xray/domain 2>/dev/null)")
    if [ -s /etc/xray/domains ]; then
        while IFS= read -r _d || [ -n "$_d" ]; do
            _d=$(echo "$_d" | tr -d '[:space:]')
            [ -n "$_d" ] && [ "$_d" != "${_all[0]}" ] && _all+=("$_d")
        done < /etc/xray/domains
    fi
    [ -z "${_all[0]}" ] && { echo "No domain configured."; return 1; }
    clear
    echo ""
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "Choose Domain"
    echo -e "${separator}"
    local i=1
    for _d in "${_all[@]}"; do
        echo -e "${green}$i${NC}. $_d"
        i=$((i+1))
    done
    echo -e "${separator}"
    echo ""
    read -p "Choose domain [1]: " nn || return 1
    [ -z "$nn" ] && nn=1
    if ! [[ "$nn" =~ ^[0-9]+$ ]] || [ "$nn" -lt 1 ] || [ "$nn" -gt "${#_all[@]}" ]; then
        echo "Invalid choice."
        return 1
    fi
    CHOSEN="${_all[$((nn-1))]}"
    local MYIP RIP
    MYIP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null)
    RIP=$(getent hosts "$CHOSEN" 2>/dev/null | awk '$1 ~ /^[0-9.]+$/ {print $1; exit}')
    if [ -n "$MYIP" ] && [ "$RIP" != "$MYIP" ]; then
        echo "Warning: $CHOSEN does not resolve here yet - issuance will fail."
        read -p "Continue anyway? (y/N): " yy || return 1
        [[ "$yy" == "y" || "$yy" == "Y" ]] || return 1
    fi
}

all_domains() {
    local primary
    primary=$(cat /etc/xray/domain 2>/dev/null)
    {
        [ -n "$primary" ] && echo "$primary"
        [ -s /etc/xray/domains ] && grep -v '^[[:space:]]*$' /etc/xray/domains | sed 's/[[:space:]]//g'
    } | awk '$0 != "" && !seen[$0]++'
}

count_ssh() {
    awk -F: '$3 >= 1000 && $1 != "nobody" {c++} END {print c+0}' /etc/passwd
}

count_xray() {
    local total=0 f sec line
    for f in /etc/xray/json/ws.json /etc/xray/json/upgrade.json /etc/xray/json/grpc.json /etc/xray/json/xhttp.json; do
        [ -f "$f" ] || continue
        sec=""
        while IFS= read -r line; do
            case "$line" in
                "#vmess") sec=vmess ;;
                "#vless") sec=vless ;;
                "#trojan") sec=trojan ;;
                "### "*) [ "$sec" = "$1" ] && total=$((total+1)) ;;
            esac
        done < "$f"
    done
    echo "$total"
}

count_mark() {
    local c
    c=$(grep -c "^### " "$1" 2>/dev/null || true)
    echo "${c:-0}"
}

count_lines() {
    local c
    c=$(grep -cve '^\s*$' "$1" 2>/dev/null || true)
    echo "${c:-0}"
}

all_domains() {
    local primary
    primary=$(cat /etc/xray/domain 2>/dev/null)
    {
        [ -n "$primary" ] && echo "$primary"
        [ -s /etc/xray/domains ] && grep -v '^[[:space:]]*$' /etc/xray/domains | sed 's/[[:space:]]//g'
    } | awk '$0 != "" && !seen[$0]++'
}

count_ssh() {
    awk -F: '$3 >= 1000 && $1 != "nobody" {c++} END {print c+0}' /etc/passwd
}

count_xray() {
    local total=0 f sec line
    for f in /etc/xray/json/ws.json /etc/xray/json/upgrade.json /etc/xray/json/grpc.json /etc/xray/json/xhttp.json; do
        [ -f "$f" ] || continue
        sec=""
        while IFS= read -r line; do
            case "$line" in
                "#vmess") sec=vmess ;;
                "#vless") sec=vless ;;
                "#trojan") sec=trojan ;;
                "### "*) [ "$sec" = "$1" ] && total=$((total+1)) ;;
            esac
        done < "$f"
    done
    echo "$total"
}

count_mark() {
    local c
    c=$(grep -c "^### " "$1" 2>/dev/null || true)
    echo "${c:-0}"
}

count_lines() {
    local c
    c=$(grep -cve '^\s*$' "$1" 2>/dev/null || true)
    echo "${c:-0}"
}

domain_extra_list() {
    clear
    echo ""
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "Domain List (all domains serve all accounts)"
    echo -e "${separator}"
    local _all _ssh _vm _vl _tr _wg _l2 _nb d
    mapfile -t _all < <(all_domains)
    if [ ${#_all[@]} -eq 0 ]; then
        echo -e "No domain configured."
        echo -e "${separator}"
        read -n 1 -s -r -p "Press any key to return..." || true
        echo ""
        return
    fi
    _ssh=$(count_ssh)
    _vm=$(count_xray vmess)
    _vl=$(count_xray vless)
    _tr=$(count_xray trojan)
    _wg=$(count_lines /etc/funny/.wireguard)
    _l2=$(count_mark /etc/funny/.l2tp)
    _nb=$(count_mark /etc/funny/.noob)
    for d in "${_all[@]}"; do
        echo -e "Domain : $d"
        printf "%-9s : %s\\n" "SSH" "$_ssh"
        printf "%-9s : %s\\n" "VMess" "$_vm"
        printf "%-9s : %s\\n" "VLess" "$_vl"
        printf "%-9s : %s\\n" "Trojan" "$_tr"
        printf "%-9s : %s\\n" "WireGuard" "$_wg"
        printf "%-9s : %s\\n" "L2TP" "$_l2"
        printf "%-9s : %s\\n" "NoobzVPN" "$_nb"
        echo -e "${separator}"
    done
    echo -e "${separator}"
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
}


dm1() {
clear
echo ""
echo ""
echo ""
echo -e "${NC}${separator}
            DOMAIN MENU
${separator}
${green}1${NC}. Add Domain
${green}2${NC}. Remove Domain
${green}3${NC}. List Domain
${green}4${NC}. Renew Certificate (Acme) - choose domain first
${green}5${NC}. Renew Certificate (Certbot) - choose domain first
${green}6${NC}. Generate Self-Signed Certificate - choose domain first
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " apw || exit 0
case $apw in
1) clear ; domain_extra_add ; dm1 ;;
2) clear ; domain_extra_del ; dm1 ;;
3) clear ; domain_extra_list ; dm1 ;;
4) clear ; pick_domain && acme ; dm1 ;;
5) clear ; pick_domain && fn ; dm1 ;;
6) clear ; pick_domain && dmsl ; dm1 ;;
0|00) clear ; menu ;;
*) clear ; dm1 ;;
esac
}

dm1
