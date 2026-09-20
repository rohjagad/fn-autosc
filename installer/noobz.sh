#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/1.23/izin.txt"
    LOCAL_IP=$(curl -s ifconfig.me) # Mendapatkan IP lokal

    # Fungsi menghitung sisa waktu
    calculate_remaining_days() {
        local today=$(date +%s)
        local expired_date=$(date -d "$1" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Tanggal kadaluwarsa tidak valid."
            exit 1
        fi
        echo $(( (expired_date - today) / 86400 ))
    }

    # Unduh izin dan validasi
    clear
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL" || { echo "Gagal mengunduh izin."; exit 1; })

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP doesn’t have on database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Izin telah kadaluwarsa."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"
    }

    output
clear
# Informasi
echo -e "\nAuto Install NoobzVPN'S by FN AutoSC"
sleep 2
clear

# [ Create Directory File ]
mkdir -p /etc/noobzvpns
touch /etc/funny/.noob

# [ Membersihkan layar ]
clear

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
wget -q -O /etc/noobzvpns/cert.pem "https://raw.githubusercontent.com/rohjagad/noobzvpns/master/cert.pem"
wget -q -O /etc/noobzvpns/key.pem "https://raw.githubusercontent.com/rohjagad/noobzvpns/master/key.pem"


# [ memberi izin pada file json & cert + key ]
chmod +x /etc/noobzvpns/*

# [ Memberi Izin Exec pada file biner ]
chmod +x /usr/bin/noobzvpns

# [ Mengambil Service yang di perlukan ]
wget -q -O /etc/systemd/system/noobzvpns.service "https://raw.githubusercontent.com/rohjagad/noobzvpns/master/noobzvpns.service"

# [ Enable & Start Service ]
systemctl enable noobzvpns
systemctl restart noobzvpns

# [ Membersihkan layar ]
clear

echo -e " Success Setup Noobzvpn's"

# [ Menghapus file tidak penting ]
rm -f /root/noobz.sh
rm -f /root/*.sh
