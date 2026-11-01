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
        REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE") || { echo "Permission data invalid."; exit 1; }
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
echo start
clear
echo ""
echo ""
selected_domain="${SELECTED_DOMAIN:-$(cat /etc/xray/installer-domain)}"
email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@$selected_domain")
clear
echo ""
echo ""
echo "
L FN 项目更新证书
${separator}
Selected Domain: $selected_domain
${blue_sep}
4 For IPv4 &  For IPv6
"
echo -e "Generate new Certificate Please Input Type Your VPS"
read -p "Input Your Type Pointing ( 4 / 6 ): " ip_version
if [[ $ip_version == "4" ]]; then
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! /root/.acme.sh/acme.sh --issue -d "$selected_domain" --force --standalone -k ec-256; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$selected_domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d "$selected_domain" --force --standalone -k ec-256 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d "$selected_domain" --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$selected_domain" -keyout /etc/xray/.xray-fallback.key.tmp -out /etc/xray/.xray-fallback.crt.tmp 2>/dev/null \
            && mv -f /etc/xray/.xray-fallback.crt.tmp /etc/xray/xray.crt \
            && mv -f /etc/xray/.xray-fallback.key.tmp /etc/xray/xray.key || rm -f /etc/xray/.xray-fallback.crt.tmp /etc/xray/.xray-fallback.key.tmp
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
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
    if ! /root/.acme.sh/acme.sh --issue -d "$selected_domain" --force --standalone -k ec-256 --listen-v6; then
        echo "Let's Encrypt failed/rate-limited, falling back to ZeroSSL..."
        /root/.acme.sh/acme.sh --set-default-ca --server zerossl
        /root/.acme.sh/acme.sh --register-account -m "${email:-admin@$selected_domain}" --server zerossl 2>/dev/null || true
        /root/.acme.sh/acme.sh --issue -d "$selected_domain" --force --standalone -k ec-256 --listen-v6 --server zerossl || true
    fi
    /root/.acme.sh/acme.sh --installcert -d "$selected_domain" --force --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc || true
    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "ACME verification failed. Generating self-signed SSL certificate fallback..."
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
            -subj "/CN=$selected_domain" -keyout /etc/xray/.xray-fallback.key.tmp -out /etc/xray/.xray-fallback.crt.tmp 2>/dev/null \
            && mv -f /etc/xray/.xray-fallback.crt.tmp /etc/xray/xray.crt \
            && mv -f /etc/xray/.xray-fallback.key.tmp /etc/xray/xray.key || rm -f /etc/xray/.xray-fallback.crt.tmp /etc/xray/.xray-fallback.key.tmp
    fi
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem
    systemctl start nginx
    systemctl restart haproxy 2>/dev/null || true
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Cert installed for IPv6."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
else
    echo "Invalid IP version. Please choose '4' for IPv4 or '6' for IPv6."
    sleep 3
    dm1
    return
fi
}






fn() {
clear
echo ""
echo ""
echo start
selected_domain="${SELECTED_DOMAIN:-$(cat /etc/xray/installer-domain)}"
systemctl stop nginx
cd /root/
clear
echo ""
echo ""
echo "Starting... Port 80 will be stopped during SSL certificate installation"
certbot certonly --standalone --preferred-challenges http --agree-tos --email "$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")" -d "$selected_domain"
if [[ -s "/etc/letsencrypt/live/$selected_domain/fullchain.pem" && -s "/etc/letsencrypt/live/$selected_domain/privkey.pem" ]]; then
    cp "/etc/letsencrypt/live/$selected_domain/fullchain.pem" /etc/xray/xray.crt
    cp "/etc/letsencrypt/live/$selected_domain/privkey.pem" /etc/xray/xray.key
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
#detail nama perusahaan
country="ID"
state="Central Kalimantan"
locality="Kab. Kota Waringin Timur"
organization="FN AutoSC"
organizationalunit="99999"
commonname="${SELECTED_DOMAIN:-FN}"
email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")

# multi-SAN self-signed via shared generator (atomic temp+mv, no live delete)
gen_selfsigned_all || { echo "Self-signed generation failed - keeping existing certificate."; read -n 1 -s -r -p "Press any key to return..." || true; echo ""; return 1; }
systemctl daemon-reload
systemctl restart haproxy 2>/dev/null || true
systemctl restart noobzvpns 2>/dev/null || true
service nginx restart
echo -e "Self-signed certificate generated successfully"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

read_installer_domain() {
    [ -s /etc/xray/installer-domain ] && tr -d '[:space:]' < /etc/xray/installer-domain
}

all_rotated_domains() {
    local installer_domain
    installer_domain=$(read_installer_domain)
    {
        [ -n "$installer_domain" ] && echo "$installer_domain"
        [ -s /etc/xray/rotated-domains ] && grep -v '^[[:space:]]*$' /etc/xray/rotated-domains | sed 's/[[:space:]]//g'
    } | awk '$0 != "" && !seen[$0]++'
}

rotated_only_domains() {
    local installer_domain d
    installer_domain=$(read_installer_domain)
    while IFS= read -r d; do
        [ -n "$d" ] && [ "$d" != "$installer_domain" ] && printf '%s\n' "$d"
    done < <(all_rotated_domains)
}

rotated_domains_sync_nginx() {
    # Rebuild the 443 server_name from installer + rotated domains.
    local installer_domain names
    installer_domain=$(read_installer_domain)
    names="$installer_domain $(tr '\n' ' ' < /etc/xray/rotated-domains 2>/dev/null)"
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
    # Self-signed covering the rotation set (auto on rotated-domain add).
    local installer_domain all san seen d
    installer_domain=$(read_installer_domain)
    all="$installer_domain $(tr '\n' ' ' < /etc/xray/rotated-domains 2>/dev/null)"
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
        -subj "/CN=$installer_domain" -addext "subjectAltName=$san" \
        -keyout /etc/xray/.xray-selfsigned.key.tmp -out /etc/xray/.xray-selfsigned.crt.tmp 2>/dev/null || { rm -f /etc/xray/.xray-selfsigned.key.tmp /etc/xray/.xray-selfsigned.crt.tmp; return 1; }
    mv -f /etc/xray/.xray-selfsigned.crt.tmp /etc/xray/xray.crt
    mv -f /etc/xray/.xray-selfsigned.key.tmp /etc/xray/xray.key
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/.funny.pem.tmp 2>/dev/null \
        && mv -f /etc/haproxy/.funny.pem.tmp /etc/haproxy/funny.pem 2>/dev/null
    chmod 600 /etc/haproxy/funny.pem 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
    systemctl restart haproxy 2>/dev/null || true
    systemctl restart noobzvpns 2>/dev/null || true
    echo "Self-signed installed for: $(echo "$san" | sed 's/DNS://g; s/,/, /g')"
}

rotated_domain_add() {
    clear
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "Add Rotated Domain"
    echo -e "${separator}"
    echo -e "Installer Domain : $(read_installer_domain)"
    echo -e "Rotated Domains (all rotate, no default):"
    local _i=1 _d
    while IFS= read -r _d; do
        [ -n "$_d" ] || continue
        printf "\e[32;1m%02d\e[0m. %s\n" "$_i" "$_d"
        _i=$((_i+1))
    done < <(rotated_only_domains)
    [ "$_i" -eq 1 ] && echo "  (none)"
    echo -e "${separator}"
    echo ""
    read -p "New rotated domain: " nd || return
    if ! [[ "$nd" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Rotated domain must be a valid DNS hostname."
        sleep 2
        return
    fi
    if all_rotated_domains | grep -qxF "$nd"; then
        echo "Rotated domain already listed."
        sleep 2
        return
    fi
    echo "$nd" >> /etc/xray/rotated-domains
    rotated_domains_sync_nginx
    echo ""
    gen_selfsigned_all
    echo ""
    echo "Note: live certificate is now self-signed (covers installer + rotated domains)."
    echo "Point DNS for $nd at this VPS IP; trusted certs via options 4/5."
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
}

rotated_domain_remove() {
    clear
    echo ""
    echo ""
    if [ ! -s /etc/xray/rotated-domains ]; then
        echo "No rotated domains yet."
        sleep 2
        return
    fi
    echo -e "${separator}"
    echo -e "Remove Rotated Domain"
    echo -e "${separator}"
    local i=1
    while IFS= read -r _d; do
        [ -n "$_d" ] && { echo -e "${green}$i${NC}. $_d"; i=$((i+1)); }
    done < /etc/xray/rotated-domains
    echo -e "${separator}"
    echo ""
    read -p "Number to remove (0 cancels): " nn || return
    if ! [[ "$nn" =~ ^[0-9]+$ ]] || [ "$nn" -lt 1 ]; then
        return
    fi
    local target
    target=$(grep -v '^\s*$' /etc/xray/rotated-domains | sed -n "${nn}p")
    [ -z "$target" ] && return
    grep -vxF "$target" /etc/xray/rotated-domains > /etc/xray/rotated-domains.tmp || true
    mv /etc/xray/rotated-domains.tmp /etc/xray/rotated-domains
    rotated_domains_sync_nginx
    echo "Removed $target."
    sleep 1
}

pick_rotated_domain() {
    # Choose one rotation entry first. Sets SELECTED_DOMAIN.
    unset SELECTED_DOMAIN
    local _all _d _installer
    _all=()
    _installer=$(read_installer_domain)
    [ -n "$_installer" ] && _all+=("$_installer")
    if [ -s /etc/xray/rotated-domains ]; then
        while IFS= read -r _d || [ -n "$_d" ]; do
            _d=$(echo "$_d" | tr -d '[:space:]')
            [ -n "$_d" ] && [ "$_d" != "$_installer" ] && _all+=("$_d")
        done < /etc/xray/rotated-domains
    fi
    [ ${#_all[@]} -eq 0 ] && { echo "No domain configured."; return 1; }
    clear
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "Choose Rotated Domain"
    echo -e "${separator}"
    local i=1
    for _d in "${_all[@]}"; do
        echo -e "${green}$i${NC}. $_d"
        i=$((i+1))
    done
    echo -e "${separator}"
    echo ""
    read -p "Choose rotated domain: " nn || return 1
    if ! [[ "$nn" =~ ^[0-9]+$ ]] || [ "$nn" -lt 1 ] || [ "$nn" -gt "${#_all[@]}" ]; then
        echo "Invalid choice."
        return 1
    fi
    SELECTED_DOMAIN="${_all[$((nn-1))]}"
    local MYIP RIP
    MYIP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null)
    RIP=$(getent hosts "$SELECTED_DOMAIN" 2>/dev/null | awk '$1 ~ /^[0-9.]+$/ {print $1; exit}')
    if [ -n "$MYIP" ] && [ "$RIP" != "$MYIP" ]; then
        echo "Warning: $SELECTED_DOMAIN does not resolve here yet - issuance will fail."
        read -p "Continue anyway? (y/N): " yy || return 1
        [[ "$yy" == "y" || "$yy" == "Y" ]] || return 1
    fi
}

count_mark() {
    local c
    c=$(grep -c "^### " "$1" 2>/dev/null || true)
    echo "${c:-0}"
}

card_rotated_domain() {
    local file="$1" d="" json="" link=""
    [ -f "$file" ] || { echo ""; return; }
    d=$(sed -n 's/^[[:space:]]*Rotated Domain[[:space:]]*:[[:space:]]*//p' "$file" 2>/dev/null | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
    [ -z "$d" ] && d=$(sed -n 's/^[[:space:]]*Rotated[[:space:]]*:[[:space:]]*//p' "$file" 2>/dev/null | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//')
    if [ -z "$d" ]; then
        link=$(grep -m1 '^vmess://' "$file" 2>/dev/null || true)
        if [ -n "$link" ]; then
            json=$(printf '%s' "${link#vmess://}" | base64 -d 2>/dev/null || true)
            d=$(printf '%s' "$json" | sed -n 's/.*"add"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
            [ -z "$d" ] && d=$(printf '%s' "$json" | sed -n 's/.*"host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        fi
    fi
    if [ -z "$d" ]; then
        link=$(grep -m1 -E '^(vless|trojan)://' "$file" 2>/dev/null || true)
        if [ -n "$link" ]; then
            d=$(printf '%s' "$link" | sed -n 's|^[a-z]*://[^@]*@\([^:/?#]*\).*|\1|p')
            [ -z "$d" ] && d=$(printf '%s' "$link" | sed -n 's/.*[?&]host=\([^&]*\).*/\1/p')
            [ -z "$d" ] && d=$(printf '%s' "$link" | sed -n 's/.*[?&]sni=\([^&]*\).*/\1/p')
        fi
    fi
    printf '%s\n' "$d"
}

card_protocol() {
    local p
    p=$(sed -n 's/^[[:space:]]*\(Protocol\|Protokol\)[[:space:]]*:[[:space:]]*//p' "$1" 2>/dev/null | head -1 | tr -d '\r' | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')
    case "$p" in
        VMESS) echo "VMess" ;;
        VLESS) echo "VLess" ;;
        TROJAN) echo "Trojan" ;;
        *) echo "" ;;
    esac
}

declare -A _DOMAIN_COUNTS=()

domain_counts_collect() {
    _DOMAIN_COUNTS=()
    local f dir p d
    for f in /var/log/create/ssh/*.log /var/log/create/ssh/*.locked; do
        [ -e "$f" ] || continue
        d=$(card_rotated_domain "$f")
        [ -n "$d" ] || d="__unknown__"
        _DOMAIN_COUNTS["SSH|$d"]=$(( ${_DOMAIN_COUNTS["SSH|$d"]:-0} + 1 ))
    done
    for dir in ws http grpc xhttp; do
        for f in /var/log/create/xray/$dir/*.log /var/log/create/xray/$dir/*.locked; do
            [ -e "$f" ] || continue
            p=$(card_protocol "$f")
            [ -n "$p" ] || continue
            d=$(card_rotated_domain "$f")
            [ -n "$d" ] || d="__unknown__"
            _DOMAIN_COUNTS["$p|$d"]=$(( ${_DOMAIN_COUNTS["$p|$d"]:-0} + 1 ))
        done
    done
    for f in /var/www/html/wireguard-*.conf; do
        [ -e "$f" ] || continue
        d=$(sed -n 's/^[[:space:]]*Endpoint[[:space:]]*=[[:space:]]*\([^:[:space:]]*\):.*/\1/p' "$f" 2>/dev/null | head -1)
        [ -n "$d" ] || d="__unknown__"
        _DOMAIN_COUNTS["WireGuard|$d"]=$(( ${_DOMAIN_COUNTS["WireGuard|$d"]:-0} + 1 ))
    done
}

print_domain_counts() {
    local label="$1" d="$2" p v total=0
    echo -e "${label} : $d"
    for p in SSH VMess VLess Trojan WireGuard; do
        v=${_DOMAIN_COUNTS["$p|$d"]:-0}
        printf "%-10s : %s\n" "$p" "$v"
        total=$((total + v))
    done
    printf "%-10s : %s\n" "Total" "$total"
    echo -e "${separator}"
}

rotated_domains_report() {
    clear
    echo ""
    echo ""
    echo -e "${separator}"
    echo -e "Domain List (per-domain account counts)"
    echo -e "${separator}"
    local installer_domain d key
    local _l2 _nb
    local -a _domains=()
    local -a _extra_list=()
    local -A _known=() _extra=()
    mapfile -t _domains < <(all_rotated_domains)
    if [ ${#_domains[@]} -eq 0 ]; then
        echo -e "No domain configured."
        echo -e "${separator}"
        read -n 1 -s -r -p "Press any key to return..." || true
        echo ""
        return
    fi
    installer_domain=$(read_installer_domain)
    domain_counts_collect
    for d in "${_domains[@]}"; do
        _known["$d"]=1
    done
    if [ -n "$installer_domain" ]; then
        print_domain_counts "Installer Domain" "$installer_domain"
    fi
    for d in "${_domains[@]}"; do
        [ "$d" = "$installer_domain" ] && continue
        print_domain_counts "Rotated Domain" "$d"
    done
    for key in "${!_DOMAIN_COUNTS[@]}"; do
        d=${key#*|}
        [ -n "${_known[$d]:-}" ] && continue
        _extra["$d"]=1
    done
    mapfile -t _extra_list < <(printf '%s\n' "${!_extra[@]}" | sort)
    for d in "${_extra_list[@]}"; do
        [ -n "$d" ] || continue
        if [ "$d" = "__unknown__" ]; then
            print_domain_counts "Unknown Domain" "$d"
        else
            print_domain_counts "Removed / Unassigned Domain" "$d"
        fi
    done
    _l2=$(count_mark /etc/funny/.l2tp)
    _nb=$(count_mark /etc/funny/.noob)
    if [ "$_l2" -gt 0 ] || [ "$_nb" -gt 0 ]; then
        echo -e "All-domain protocols (no single rotated domain)"
        printf "%-10s : %s\n" "L2TP" "$_l2"
        printf "%-10s : %s\n" "NoobzVPN" "$_nb"
        echo -e "${separator}"
    fi
    read -n 1 -s -r -p "Press any key to return..." || true
    echo ""
}

dm1() {
clear
local installer_domain rotated_list
installer_domain=$(read_installer_domain)
rotated_list=$(rotated_only_domains | awk 'NR>1{printf ", "} {printf "%s",$0}')
echo ""
echo ""
echo -e "${NC}${separator}
            DOMAIN MENU
${separator}
Installer Domain : ${installer_domain:-not set}
Rotated Domains  : ${rotated_list:-none}
${blue_sep}
${green}1${NC}. Add Rotated Domain
${green}2${NC}. Remove Rotated Domain
${green}3${NC}. List Domains / Account Counts
${green}4${NC}. Renew Certificate (Acme) - choose domain first
${green}5${NC}. Renew Certificate (Certbot) - choose domain first
${green}6${NC}. Generate Self-Signed Certificate - choose domain first
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " apw || exit 0
case $apw in
1) clear ; rotated_domain_add ; dm1 ;;
2) clear ; rotated_domain_remove ; dm1 ;;
3) clear ; rotated_domains_report ; dm1 ;;
4) clear ; pick_rotated_domain && acme ; dm1 ;;
5) clear ; pick_rotated_domain && fn ; dm1 ;;
6) clear ; pick_rotated_domain && dmsl ; dm1 ;;
0|00) clear ; menu ;;
*) clear ; dm1 ;;
esac
}

dm1
