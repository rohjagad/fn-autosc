#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear

# Fungsi untuk membaca file
read_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cat "$file_path" | tr -d '\n'
    else
        echo ""
    fi
}

# Fungsi untuk mengirim notifikasi Telegram
send_telegram_notification() {
    local chat_id="$1"
    local key="$2"
    local message="$3"

    curl -s -X POST "https://api.telegram.org/bot${key}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${message}" > /dev/null
}

# Fungsi untuk membuat pengguna SSH
create_ssh_user() {
    local username="$1"
    local password="$2"

    # Tambahkan pengguna tanpa home directory dan shell /bin/false
    useradd -s /bin/false -M "$username"
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal membuat pengguna $username."
        return 1
    fi

    # Setel password pengguna
    echo -e "${password}\n${password}" | passwd "$username" > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal mengatur password untuk $username."
        return 1
    fi

    return 0
}

# Fungsi untuk menjadwalkan penghapusan pengguna
schedule_user_expiration() {
    local username="$1"
    local minutes="$2"

    # Buat perintah untuk memutus koneksi dan menghapus pengguna
    local disconnect_cmd="pkill -u $username"
    local delete_cmd="userdel -f $username"

    # Jadwalkan dengan `at`
    echo "${disconnect_cmd}; ${delete_cmd}" | at now + "$minutes" minutes > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Error: Gagal menjadwalkan penghapusan pengguna $username."
        return 1
    fi

    return 0
}

# Baca konfigurasi
domain=$(read_file "/etc/xray/domain")
pub_key=$(read_file "/etc/slowdns/server.pub")
nameserver=$(read_file "/etc/slowdns/nsdomain")
chat_id=$(read_file "/etc/funny/.chatid")
key=$(read_file "/etc/funny/.keybot")

echo "===================="
echo " Create SSH Account "
echo "===================="
read -p "Expired (minutes): " masaaktif

clear

# Buat username dan password otomatis
username="trial$(shuf -i 100-999 -n 1)"
password="1"

# Buat pengguna SSH
create_ssh_user "$username" "$password"
if [[ $? -ne 0 ]]; then
    exit 1
fi

# Jadwalkan penghapusan pengguna
schedule_user_expiration "$username" "$masaaktif"
if [[ $? -ne 0 ]]; then
    exit 1
fi

# Buat pesan notifikasi
message=$(cat <<EOF
===================
[<= SSH Account =>]
===================
Domain     : $domain
Username   : $username
Password   : $password
Expired    : $masaaktif Minutes
Limit IP   : 1
===================
DNS        : 1.1.1.1 / 8.8.8.8
Pub Key    : $pub_key
Nameserver : $nameserver
===================
OpenSSH    : 22, 3303
Dropbear   : 111, 109
NonTLS     : 80, 8880, 2052, 2082, 2086, 2095
Enhanced   : 2080
HTTP Proxy : 3128 ( Limit IP to Server )
OHP        : 9088
WS TLS     : 443, 2053, 2083, 2087, 2096
STUNNEL5   : 443
Slowdns    : 53
Udp Custom : 1-65535
Udp Request: 1-65535
BadVpn/Udpgw : 7300
===================
OVPN WS     : 2086
OVPN TCP    : 1194
Config OVPN : http://${domain}/web/tcp.ovpn
===================
EOF
)

# Kirim notifikasi ke Telegram
send_telegram_notification "$chat_id" "$key" "$message"

clear
echo "$message"
