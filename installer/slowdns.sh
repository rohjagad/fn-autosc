#!/bin/bash

# Add the fallback resolver once.  The old test also appended when curl was
# missing even if 1.1.1.1 was already present, leaving duplicate lines on
# repeated installs.  Only touch a static file, never a resolver-managed
# symlink.
if [ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ] && \
   ! grep -qx 'nameserver 1\.1\.1\.1' /etc/resolv.conf 2>/dev/null; then
    printf 'nameserver 1.1.1.1\n' | cat - /etc/resolv.conf > /etc/resolv.conf.tmp && \
        mv /etc/resolv.conf.tmp /etc/resolv.conf
fi


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
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
echo "Please Wait ...."
REQUIRED_PACKAGES=("curl" "wget" "tar" "coreutils" "iptables" "iproute2" "dnsutils")
for package in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg-query -W --showformat='${Status}\n' "$package" 2>/dev/null | grep -q "install ok installed"; then
    apt-get -qq install "$package" -y &>/dev/null || true
  fi
done
clear
echo ""
echo ""

# Found 550: ePro's official SlowDNS server is the only server.  The vendor
# tarball is uploaded to the miscellaneous release; the SHA-256 pin makes a
# wrong or truncated download fail closed.  The package is amd64-only.  A
# failed reinstall leaves a running service untouched until the old unit is
# actually stopped and backed up.
#
# Fix 552: v8.1.5.942 is ePro's HC-only build and the matching server for
# HTTP Custom 8.1.5.942.  Build 934 and older clients must update the app
# before connecting.  The vendor install.sh and the saved keys/nsdomain are
# reused, so an in-place update keeps the same public key and nameserver.
SLOWDNS_EPRO_RELEASE="v8.1.5.942"
SLOWDNS_EPRO_URL="https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/${SLOWDNS_EPRO_RELEASE}/slowdns-linux-amd64.tar.gz"
SLOWDNS_EPRO_SHA256="a0799f9a3cfb9b5a7633af4d8c38dede50e89f0c33e2f5ad42b8c3ad1ae97895"
SLOWDNS_EPRO_BIN_SHA256="4a455c89e219cc7d045beaf425f3870a023056bbe593aeb9be55f2f2948f98b7"
SLOWDNS_DIR="/etc/slowdns"
SLOWDNS_TMP=""
SLOWDNS_UDP_ADDR=""
SLOWDNS_DIRECT_BINDINGS=""
SLOWDNS_DOMAIN=""
SLOWDNS_OLD_SERVICE=""
SLOWDNS_BACKUP=""
SLOWDNS_CHANGED=0

say() { echo "SlowDNS: $*"; }
fail() { echo "SlowDNS: $*" >&2; return 1; }

cleanup_slowdns_tmp() {
    [ -n "$SLOWDNS_TMP" ] && rm -rf "$SLOWDNS_TMP"
    SLOWDNS_TMP=""
}
trap cleanup_slowdns_tmp EXIT

valid_hostname() {
    [[ "$1" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]
}

download_epro_package() {
    SLOWDNS_TMP=$(mktemp -d) || { fail "cannot create a temporary directory"; return 1; }
    local archive="$SLOWDNS_TMP/slowdns-linux-amd64.tar.gz"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 600 --retry 2 --retry-delay 5 "$SLOWDNS_EPRO_URL" -o "$archive" || {
            fail "could not download $SLOWDNS_EPRO_URL"; return 1;
        }
    else
        wget -q --timeout=600 --tries=3 -O "$archive" "$SLOWDNS_EPRO_URL" || {
            fail "could not download $SLOWDNS_EPRO_URL"; return 1;
        }
    fi
    if ! printf '%s  %s\n' "$SLOWDNS_EPRO_SHA256" "$archive" | sha256sum -c - >/dev/null 2>&1; then
        fail "package checksum mismatch"; return 1
    fi
    tar -xzf "$archive" -C "$SLOWDNS_TMP" 2>/dev/null || { fail "cannot extract the package"; return 1; }
    [ -x "$SLOWDNS_TMP/slowdns" ] || { fail "package has no slowdns binary"; return 1; }
    [ -f "$SLOWDNS_TMP/install.sh" ] || { fail "package has no install.sh"; return 1; }
    if [ "$(sha256sum "$SLOWDNS_TMP/slowdns" | awk '{print $1}')" != "$SLOWDNS_EPRO_BIN_SHA256" ]; then
        fail "package binary checksum mismatch"; return 1
    fi
    return 0
}

port53_listening() {
    ss -H -lun 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:|\])53$'
}

primary_ip() {
    local ip=""
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    ip=$(ip -6 route get 2606:4700:4700::1111 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    ip=$(ip -o -4 addr show scope global 2>/dev/null | awk 'NR==1{split($4,a,"/"); print a[1]}')
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    ip=$(ip -o -6 addr show scope global 2>/dev/null | awk 'NR==1{split($4,a,"/"); print a[1]}')
    [ -n "$ip" ] && echo "$ip"
}

iface_for_ip() {
    ip -o addr show 2>/dev/null | awk -v ip="$1" '
        {
            addr=$4; sub(/\/.*/, "", addr); iface=$2; sub(/@.*/, "", iface)
            if (addr == ip) { print iface; exit }
        }'
}

bindings_all() {
    {
        ip -o -4 addr show scope global 2>/dev/null
        ip -o -6 addr show scope global 2>/dev/null
    } | awk '{
        addr=$4; sub(/\/.*/, "", addr); iface=$2; sub(/@.*/, "", iface)
        if (addr != "" && iface != "") print addr "," iface
    }' | sort -u | paste -sd' ' -
}

choose_listener() {
    local ip="" iface=""
    SLOWDNS_UDP_ADDR=""
    SLOWDNS_DIRECT_BINDINGS=""
    if ! port53_listening; then
        SLOWDNS_UDP_ADDR=":53"
        SLOWDNS_DIRECT_BINDINGS=$(bindings_all)
        return 0
    fi
    ip=$(primary_ip)
    [ -n "$ip" ] || { fail "UDP 53 is in use and no global IP was found"; return 1; }
    case "$ip" in
        *:*) SLOWDNS_UDP_ADDR="[$ip]:53" ;;
        *) SLOWDNS_UDP_ADDR="$ip:53" ;;
    esac
    iface=$(iface_for_ip "$ip")
    [ -n "$iface" ] && SLOWDNS_DIRECT_BINDINGS="$ip,$iface"
    return 0
}

write_env() {
    cat > "$SLOWDNS_DIR/slowdns.env" <<EOF
SLOWDNS_BINARY="slowdns"
SLOWDNS_UDP_ADDR="$SLOWDNS_UDP_ADDR"
SLOWDNS_PRIVKEY_FILE="$SLOWDNS_DIR/server.key"
SLOWDNS_DOMAIN="$SLOWDNS_DOMAIN"
SLOWDNS_UPSTREAM_ADDR="127.0.0.1:22"
SLOWDNS_EXTRA_ARGS="-diagnostics"
SLOWDNS_DIRECT_IPV4=""
SLOWDNS_DIRECT_INTERFACE=""
SLOWDNS_DIRECT_BINDINGS="$SLOWDNS_DIRECT_BINDINGS"
EOF
    chmod 600 "$SLOWDNS_DIR/slowdns.env"
}

run_epro_install() {
    local log="$SLOWDNS_TMP/install.log"
    if "$SLOWDNS_DIR/install.sh" install >"$log" 2>&1; then
        return 0
    fi
    if [ -n "$SLOWDNS_DIRECT_BINDINGS" ]; then
        say "NOTRACK setup failed; retrying without it."
        systemctl stop slowdns.service 2>/dev/null || true
        systemctl disable slowdns.service 2>/dev/null || true
        rm -f /etc/systemd/system/slowdns.service
        systemctl daemon-reload 2>/dev/null || true
        SLOWDNS_DIRECT_BINDINGS=""
        write_env
        if "$SLOWDNS_DIR/install.sh" install >>"$log" 2>&1; then
            return 0
        fi
    fi
    tail -n 20 "$log" >&2 2>/dev/null || true
    return 1
}

add_firewall_rule() {
    iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    ip6tables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || \
        ip6tables -I INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
    fi
}

# udp-request inserts wildcard UDP captures at the top of nat PREROUTING when
# it starts.  The panel's request installer already exempts its own UDP
# services; add 53 there so a direct SlowDNS listener is not swallowed.
add_udp53_bypass() {
    local f="/usr/local/bin/udp-request-fixnet.sh" list=""
    [ -f "$f" ] || return 0
    list=$(sed -n 's/^[[:space:]]*for p in \(.*\); do$/\1/p' "$f" 2>/dev/null | head -n 1)
    if [ -n "$list" ]; then
        case " $list " in
            *" 53 "*) ;;
            *) sed -i -E 's/^([[:space:]]*)for p in (.*); do$/\1for p in 53 \2; do/' "$f" 2>/dev/null || true ;;
        esac
    elif ! grep -qE 'dport[[:space:]]+53([^0-9]|$)' "$f" 2>/dev/null; then
        sed -i '/^[[:space:]]*exit 0[[:space:]]*$/i while iptables -t nat -D PREROUTING -p udp --dport 53 -j RETURN 2>/dev/null; do :; done\niptables -t nat -I PREROUTING 1 -p udp --dport 53 -j RETURN' "$f" 2>/dev/null || true
    fi
    systemctl restart udp-request-fixnet.timer 2>/dev/null || true
    "$f" >/dev/null 2>&1 || true
}

rollback_slowdns() {
    local old_service="$1" dir="$SLOWDNS_DIR" b="$SLOWDNS_BACKUP"
    # Nothing was stopped or replaced yet (for example, the download failed):
    # leave the running service exactly as it was.
    [ "$SLOWDNS_CHANGED" -eq 1 ] || return 0
    # Stop the new unit even when an old ePro unit is being restored, so its
    # ExecStopPost removes any NOTRACK rules it added.
    systemctl stop slowdns.service 2>/dev/null || true
    if [ "$old_service" != "slowdns" ]; then
        systemctl disable slowdns.service 2>/dev/null || true
        rm -f /etc/systemd/system/slowdns.service
    fi
    case "$old_service" in
        slowdns)
            [ -f "$b/slowdns" ] && install -m 0755 "$b/slowdns" "$dir/slowdns" 2>/dev/null || true
            [ -f "$b/install.sh" ] && install -m 0755 "$b/install.sh" "$dir/install.sh" 2>/dev/null || true
            [ -f "$b/slowdns.env" ] && cp -f "$b/slowdns.env" "$dir/slowdns.env" 2>/dev/null || true
            [ -f "$b/slowdns.service" ] && cp -f "$b/slowdns.service" /etc/systemd/system/slowdns.service 2>/dev/null || true
            systemctl daemon-reload 2>/dev/null || true
            systemctl start slowdns.service 2>/dev/null || true
            ;;
    esac
    systemctl daemon-reload 2>/dev/null || true
}

install_slowdns() {
    local key="$SLOWDNS_DIR/server.key" pub="$SLOWDNS_DIR/server.pub"
    local old_key_hash="" old_pub_hash=""

    case "$(uname -m)" in
        x86_64|amd64) ;;
        *)
            say "the official ePro package is amd64-only; skipping on $(uname -m)."
            return 0
            ;;
    esac

    download_epro_package || return 1

    mkdir -p "$SLOWDNS_DIR" || { fail "cannot create $SLOWDNS_DIR"; return 1; }
    chmod 0755 "$SLOWDNS_DIR" 2>/dev/null || true
    if [ -s "$SLOWDNS_DIR/nsdomain" ]; then
        SLOWDNS_DOMAIN=$(tr -d '[:space:]' < "$SLOWDNS_DIR/nsdomain")
    fi
    if [ -z "$SLOWDNS_DOMAIN" ]; then
        read -rp "Your Nameserver: " SLOWDNS_DOMAIN || return 1
        SLOWDNS_DOMAIN=$(printf '%s' "$SLOWDNS_DOMAIN" | tr -d '[:space:]')
        [ -n "$SLOWDNS_DOMAIN" ] || { fail "nameserver cannot be empty"; return 1; }
        printf '%s\n' "$SLOWDNS_DOMAIN" > "$SLOWDNS_DIR/nsdomain"
    fi
    valid_hostname "$SLOWDNS_DOMAIN" || { fail "invalid nameserver: $SLOWDNS_DOMAIN"; return 1; }

    if [ -s "$key" ]; then
        [ -s "$pub" ] || { fail "$pub is missing; restore it or remove $key to generate a new pair"; return 1; }
        chmod 600 "$key" 2>/dev/null || true
        chmod 644 "$pub" 2>/dev/null || true
        old_key_hash=$(sha256sum "$key" | awk '{print $1}')
        old_pub_hash=$(sha256sum "$pub" | awk '{print $1}')
    fi

    if systemctl is-active --quiet slowdns.service 2>/dev/null; then
        SLOWDNS_OLD_SERVICE="slowdns"
    fi
    SLOWDNS_BACKUP="/root/fn-slowdns-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$SLOWDNS_BACKUP" 2>/dev/null || SLOWDNS_BACKUP=""
    if [ -n "$SLOWDNS_OLD_SERVICE" ] && [ -z "$SLOWDNS_BACKUP" ]; then
        fail "cannot create a rollback backup; leaving the running service untouched"
        return 1
    fi
    if [ -n "$SLOWDNS_BACKUP" ]; then
        [ -x "$SLOWDNS_DIR/slowdns" ] && cp -f "$SLOWDNS_DIR/slowdns" "$SLOWDNS_BACKUP/slowdns" 2>/dev/null || true
        [ -f "$SLOWDNS_DIR/install.sh" ] && cp -f "$SLOWDNS_DIR/install.sh" "$SLOWDNS_BACKUP/install.sh" 2>/dev/null || true
        [ -f "$SLOWDNS_DIR/slowdns.env" ] && cp -f "$SLOWDNS_DIR/slowdns.env" "$SLOWDNS_BACKUP/slowdns.env" 2>/dev/null || true
        [ -f /etc/systemd/system/slowdns.service ] && cp -f /etc/systemd/system/slowdns.service "$SLOWDNS_BACKUP/slowdns.service" 2>/dev/null || true
    fi
    SLOWDNS_CHANGED=1
    systemctl stop slowdns.service 2>/dev/null || true
    pkill -x slowdns 2>/dev/null || true
    rm -f /etc/systemd/system/slowdns.service
    systemctl daemon-reload 2>/dev/null || true

    install -m 0755 "$SLOWDNS_TMP/slowdns" "$SLOWDNS_DIR/slowdns" || { fail "cannot install slowdns"; return 1; }
    install -m 0755 "$SLOWDNS_TMP/install.sh" "$SLOWDNS_DIR/install.sh" || { fail "cannot install install.sh"; return 1; }
    install -m 0644 "$SLOWDNS_TMP/README.md" "$SLOWDNS_DIR/README.epro.md" 2>/dev/null || true

    if [ ! -s "$key" ]; then
        "$SLOWDNS_DIR/slowdns" -gen-key -privkey-file "$key" -pubkey-file "$pub" || {
            fail "key generation failed"; return 1;
        }
    fi
    chmod 600 "$key" 2>/dev/null || true
    chmod 644 "$pub" 2>/dev/null || true

    choose_listener || return 1
    write_env || { fail "cannot write slowdns.env"; return 1; }
    run_epro_install || { fail "the ePro installer failed"; return 1; }
    systemctl is-active --quiet slowdns.service || { fail "slowdns.service is not active"; return 1; }

    if [ -n "$old_key_hash" ]; then
        [ "$(sha256sum "$key" | awk '{print $1}')" = "$old_key_hash" ] || { fail "server.key changed unexpectedly"; return 1; }
        [ "$(sha256sum "$pub" | awk '{print $1}')" = "$old_pub_hash" ] || { fail "server.pub changed unexpectedly"; return 1; }
    fi

    add_firewall_rule
    add_udp53_bypass

    systemctl daemon-reload 2>/dev/null || true

    if grep -q '^#AllowTcpForwarding yes' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's/^#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    fi

    say "installed; service is active on UDP 53 (HC 8.1.5.942 build)."
    say "HTTP Custom build 934 and older must update the app before connecting."
    echo "Nameserver : $SLOWDNS_DOMAIN"
    echo "Public key : $(cat "$pub" 2>/dev/null)"
    echo "Service    : systemctl status slowdns"
    echo "Logs       : journalctl -u slowdns -f"
    return 0
}

if ! install_slowdns; then
    echo "SlowDNS installation failed." >&2
    rollback_slowdns "$SLOWDNS_OLD_SERVICE"
    exit 1
fi
rm -rf /root/slowdns.sh
clear
echo ""
echo ""
echo -e "Installing Patch SlowDNS Autoscript done..."
echo "done .."
#reboot
