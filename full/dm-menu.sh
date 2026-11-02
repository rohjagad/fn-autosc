#!/bin/bash
# Found 525: license is enforced only for create/extend/install.
# Found 541: deleting a rotated domain also removes its certificate and ACME
# state; services are reloaded, never restarted, so existing sessions stay up.
# Found 542: reassigned account cards are spread across the remaining domains
# by current count, keeping the rotation balanced.


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || {
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
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
    # The rotation list is independent: the installer domain is not implicit.
    [ -s /etc/xray/rotated-domains ] || return 0
    grep -v '^[[:space:]]*$' /etc/xray/rotated-domains | sed 's/[[:space:]]//g' | awk '$0 != "" && !seen[$0]++'
}

rotated_domains_sync_nginx() {
    # Rebuild the 443 server_name from installer + rotated domains.
    local installer_domain names
    installer_domain=$(read_installer_domain)
    names=$(
        {
            [ -n "$installer_domain" ] && printf '%s\n' "$installer_domain"
            [ -s /etc/xray/rotated-domains ] && cat /etc/xray/rotated-domains
        } | sed 's/[[:space:]]//g' | awk 'NF && !seen[$0]++ {printf "%s%s", sep, $0; sep=" "}'
    )
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
    # Argument "graceful" reloads services instead of restarting them (Fix 541).
    local mode="${1:-restart}"
    local installer_domain all san seen d
    installer_domain=$(read_installer_domain)
    [ -z "$installer_domain" ] && installer_domain=$(all_rotated_domains | head -1)
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
    if [ "$mode" = "graceful" ]; then
        # Found 541: a reload keeps established sessions up.  Do not restart
        # noobzvpns here; it has no reload and a restart would drop clients.
        nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true
        if [ -f /etc/haproxy/haproxy.cfg ] && command -v haproxy >/dev/null 2>&1 && systemctl is-active --quiet haproxy 2>/dev/null; then
            haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 && systemctl reload haproxy 2>/dev/null || true
        fi
    else
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
        systemctl restart haproxy 2>/dev/null || true
        systemctl restart noobzvpns 2>/dev/null || true
    fi
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
    done < <(all_rotated_domains)
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

cert_is_selfsigned() {
    [ -s /etc/xray/xray.crt ] || return 1
    local subj iss
    subj=$(openssl x509 -in /etc/xray/xray.crt -noout -subject 2>/dev/null | sed 's/^subject=//')
    iss=$(openssl x509 -in /etc/xray/xray.crt -noout -issuer 2>/dev/null | sed 's/^issuer=//')
    [ -n "$subj" ] && [ "$subj" = "$iss" ]
}

domain_remove_cert_state() {
    # Found 541: remove only this domain's ACME/Certbot state.  The live
    # certificate copy is replaced separately, after the domain list is gone.
    local d="$1"
    [ -n "$d" ] || return 0
    [[ "$d" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]] || return 0
    rm -rf "/etc/letsencrypt/live/$d" "/etc/letsencrypt/archive/$d" "/etc/letsencrypt/renewal/$d.conf" 2>/dev/null || true
    rm -rf "/root/.acme.sh/$d" "/root/.acme.sh/${d}_ecc" 2>/dev/null || true
}

domain_reassign_cards() {
    # Found 542: a deleted domain must not survive in account cards.  Rewrite
    # only the exact hostname, keeping every UUID/password/expiry unchanged,
    # and spread the cards over the remaining domains by current count so the
    # distribution stays balanced.  Base64 vmess:// payloads are decoded too.
    local old="$1"
    shift
    local -a candidates=("$@")
    [ -n "$old" ] && [ ${#candidates[@]} -gt 0 ] || return 0
    python3 - "$old" "${candidates[@]}" <<'PY542'
import base64, pathlib, re, sys
old = sys.argv[1]
candidates = sys.argv[2:]
pattern = re.compile(r'(?<![A-Za-z0-9.-])' + re.escape(old) + r'(?![A-Za-z0-9.-])')
root = pathlib.Path('/var/log/create')
files = sorted(p for p in root.rglob('*') if p.is_file() and p.suffix in ('.log', '.locked'))
counts = {d: 0 for d in candidates}

def replace_vmess(text, new):
    def repl(match):
        raw = match.group(1)
        try:
            data = base64.b64decode(raw + '=' * (-len(raw) % 4), validate=False)
            decoded = data.decode('utf-8')
        except Exception:
            try:
                data = base64.urlsafe_b64decode(raw + '=' * (-len(raw) % 4))
                decoded = data.decode('utf-8')
            except Exception:
                return match.group(0)
        fixed = pattern.sub(new, decoded)
        if fixed == decoded:
            return match.group(0)
        return 'vmess://' + base64.b64encode(fixed.encode('utf-8')).decode('ascii')
    return re.sub(r'vmess://([A-Za-z0-9+/=_-]+)', repl, text)

for path in files:
    try:
        text = path.read_text(errors='ignore')
    except OSError:
        continue
    match = re.search(r'^[ \t]*Rotated Domain[ \t]*:[ \t]*(\S+)', text, re.M)
    if match and match.group(1) in counts:
        counts[match.group(1)] += 1

moved = 0
for path in files:
    try:
        text = path.read_text(errors='ignore')
    except OSError:
        continue
    dest = min(candidates, key=lambda d: (counts[d], candidates.index(d)))
    updated = pattern.sub(dest, text)
    updated = replace_vmess(updated, dest)
    if updated == text:
        continue
    try:
        path.write_text(updated)
    except OSError:
        continue
    counts[dest] += 1
    moved += 1

if moved:
    summary = ', '.join(f'{d}={counts[d]}' for d in candidates)
    print(f'Reassigned {moved} account card(s): {summary}.')
PY542
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
    rotated_domains_sync_nginx || true

    # Found 541: remove every trace of the domain, but use reloads only so
    # established sessions are not dropped.  The default Nginx 443 server
    # remains, so arbitrary SNI + allowInsecure keeps working.
    local installer_domain refs
    installer_domain=$(read_installer_domain)
    if [ "$target" = "$installer_domain" ]; then
        echo "Removed $target from the rotated list; the installer domain itself is unchanged."
    else
        echo "Removed $target."
        domain_remove_cert_state "$target"
        if cert_is_selfsigned; then
            if gen_selfsigned_all graceful; then
                echo "Certificate SAN updated: $target removed."
            else
                echo "Warning: certificate update failed; $target may remain in the SAN."
            fi
        else
            echo "Warning: the active certificate is CA-issued and still contains $target."
            echo "Reissue it from the certificate menu to remove that name."
        fi
    fi
    refs=$(grep -RFl -- "$target" /var/log/create 2>/dev/null | wc -l)
    if [ "${refs:-0}" -gt 0 ] && [ "$target" != "$installer_domain" ]; then
        local -a replacements=()
        local d
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            [ "$d" = "$target" ] && continue
            replacements+=("$d")
        done < <(all_rotated_domains)
        if [ ${#replacements[@]} -eq 0 ] && [ -n "$installer_domain" ] && [ "$installer_domain" != "$target" ]; then
            replacements+=("$installer_domain")
        fi
        if [ ${#replacements[@]} -gt 0 ]; then
            domain_reassign_cards "$target" "${replacements[@]}"
        else
            echo "Warning: $refs account card(s) still mention $target and no replacement domain is available."
        fi
    fi
    if [ ! -s /etc/xray/rotated-domains ]; then
        echo "Rotated list is now empty. Xray/SSH/WireGuard account creation will stop until a domain is added."
    fi
    sleep 2
}

pick_certificate_domain() {
    # Certificate selection may include the installer domain even when the
    # rotated list is empty. Sets SELECTED_DOMAIN.
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
    echo -e "Choose Certificate Domain"
    echo -e "${separator}"
    local i=1
    for _d in "${_all[@]}"; do
        echo -e "${green}$i${NC}. $_d"
        i=$((i+1))
    done
    echo -e "${separator}"
    echo ""
    read -p "Choose certificate domain: " nn || return 1
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
    installer_domain=$(read_installer_domain)
    if [ ${#_domains[@]} -eq 0 ] && [ -z "$installer_domain" ]; then
        echo -e "No domain configured."
        echo -e "${separator}"
        read -n 1 -s -r -p "Press any key to return..." || true
        echo ""
        return
    fi
    domain_counts_collect
    for d in "${_domains[@]}"; do
        _known["$d"]=1
    done
    [ -n "$installer_domain" ] && _known["$installer_domain"]=1

    echo -e "Installer Domain : ${installer_domain:-not set}"
    if [ ${#_domains[@]} -eq 0 ]; then
        echo -e "Rotated Domains  : (empty)"
        echo -e "Add a rotated domain before creating Xray, SSH, or WireGuard accounts."
        echo -e "${separator}"
    else
        echo -e "Rotated Domains  :"
        for d in "${_domains[@]}"; do
            if [ "$d" = "$installer_domain" ]; then
                print_domain_counts "Rotated Domain (installer domain, removable)" "$d"
            else
                print_domain_counts "Rotated Domain" "$d"
            fi
        done
    fi

    # Accounts may still point at an installer domain removed from the rotated
    # list. Show those counts separately instead of hiding them.
    if [ -n "$installer_domain" ] && ! printf '%s\n' "${_domains[@]}" | grep -qxF "$installer_domain"; then
        local _itotal=0 _p
        for _p in SSH VMess VLess Trojan WireGuard; do
            _itotal=$((_itotal + ${_DOMAIN_COUNTS["$_p|$installer_domain"]:-0}))
        done
        if [ "$_itotal" -gt 0 ]; then
            print_domain_counts "Installer Domain (not in rotated list)" "$installer_domain"
        fi
    fi
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
rotated_list=$(all_rotated_domains | awk 'NR>1{printf ", "} {printf "%s",$0}')
echo ""
echo ""
echo -e "${NC}${separator}
            DOMAIN MENU
${separator}
Installer Domain : ${installer_domain:-not set}
Rotated Domains  : ${rotated_list:-(empty)}
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
4) clear ; pick_certificate_domain && acme ; dm1 ;;
5) clear ; pick_certificate_domain && fn ; dm1 ;;
6) clear ; pick_certificate_domain && dmsl ; dm1 ;;
0|00) clear ; menu ;;
*) clear ; dm1 ;;
esac
}

dm1
