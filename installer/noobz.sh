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
echo ""
echo ""
# Informasi
echo -e "\nAuto Install NoobzVPN'S by FN AutoSC"
sleep 2
clear
echo ""
echo ""
echo ""
echo ""
echo ""
# [ Create Directory File ]
mkdir -p /etc/noobzvpns
touch /etc/funny/.noob

# [ Membersihkan layar ]
clear
echo ""
echo ""
echo ""
echo ""
echo ""
# [ Membuat Json Config yang di gunakan pada server ]
cat > /etc/noobzvpns/config.json <<-JSON
{
	"tcp_std": [
		8080
	],
	"tcp_ssl": [
		8443
	],
	"ssl_cert": "/etc/noobzvpns/cert.pem",
	"ssl_key": "/etc/noobzvpns/key.pem",
	"ssl_version": "AUTO",
	"conn_timeout": 60,
	"dns_resolver": "/etc/resolv.conf",
	"http_ok": "HTTP/1.1 101 Switching Protocols[crlf]Upgrade: websocket[crlf][crlf]"
}
JSON
# [ Membuat TOML Config yang dibaca server, bind IPv4 saja agar tidak gagal di VPS tanpa IPv6 ]
cat > /etc/noobzvpns/config.toml <<-TOML
[tcp_plain]
local_host = ["0.0.0.0:8080"]
[tcp_ssl]
local_host = ["0.0.0.0:8443"]
tls_version = "AUTO"
key_pem = "/etc/noobzvpns/key.pem"
cert_pem = "/etc/noobzvpns/cert.pem"
[client]
ip_version = "AUTO"
tcp_initial_timeout = 30
resolv_conf = "/etc/resolv.conf"
identifier = "noobz-id.github.io"
banner = "You are connected to noobzvpn-server"
tcp_http_response = "HTTP/1.1 101 Switching Protocols\\r\\nUpgrade: websocket\\r\\nConnection: Upgrade\\r\\n\\r\\n"
[remote]
tcp_connect_timeout = 30
tcp_idle_timeout = 900
udp_connect_timeout = 30
udp_idle_timeout = 60
udp_dns_timeout = 10
[database]
database_monitor_timer = 30
device_timeout = 5
[runtime]
worker_threads = 0
TOML
# Port Dari tcp_std & tcp_ssl edit sesuai kemauan kalian agar tidak bentrok dengan service lain pada vps kalian


# [ wget ambil file ]
wget -q -O /usr/bin/noobzvpns "https://raw.githubusercontent.com/rohjagad/noobzvpns/master/noobzvpns.x86-64"
# Use the domain certificate issued by diamond.sh instead of generic GitHub certs
ln -sf /etc/xray/xray.crt /etc/noobzvpns/cert.pem
ln -sf /etc/xray/xray.key /etc/noobzvpns/key.pem


# [ memberi izin pada file json & cert + key ]
chmod 600 /etc/noobzvpns/config.json /etc/noobzvpns/config.toml 2>/dev/null || true
# Do not chmod the cert.pem/key.pem symlinks - they point to /etc/xray/xray.{crt,key} (0644/0600)

# [ Memberi Izin Exec pada file biner ]
chmod +x /usr/bin/noobzvpns

# [ Mengambil Service yang di perlukan ]
wget -q -O /etc/systemd/system/noobzvpns.service "https://raw.githubusercontent.com/rohjagad/noobzvpns/master/noobzvpns.service"

# [ Enable & Start Service ]
systemctl enable noobzvpns
systemctl restart noobzvpns

# [ Membersihkan layar ]
clear
echo ""
echo ""
echo ""
echo ""
echo ""
echo -e " Success Setup Noobzvpn's"

# [ Menghapus file tidak penting ]
rm -f /root/noobz.sh
