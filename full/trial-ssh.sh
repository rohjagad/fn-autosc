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
    local delete_cmd="userdel -f $username; rm -f /var/log/create/ssh/${username}.log /etc/xray/limit/ip/ssh/${username}"

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

echo -e "\033[38;2;255;0;0m-\033[38;2;255;80;0m-\033[38;2;255;161;0m-\033[38;2;255;241;0m-\033[38;2;188;255;0m-\033[38;2;108;255;0m-\033[38;2;27;255;0m-\033[38;2;0;255;53m-\033[38;2;0;255;134m-\033[38;2;0;255;214m-\033[38;2;0;215;255m-\033[38;2;0;135;255m-\033[38;2;0;54;255m-\033[38;2;26;0;255m-\033[38;2;107;0;255m-\033[38;2;187;0;255m-\033[38;2;255;0;242m-\033[38;2;255;0;162m-\033[38;2;255;0;81m-\033[38;2;255;0;0m-\033[0m"
echo -e "\033[1;33m Create SSH Account \033[0m"
echo -e "\033[38;2;255;0;0m-\033[38;2;255;80;0m-\033[38;2;255;161;0m-\033[38;2;255;241;0m-\033[38;2;188;255;0m-\033[38;2;108;255;0m-\033[38;2;27;255;0m-\033[38;2;0;255;53m-\033[38;2;0;255;134m-\033[38;2;0;255;214m-\033[38;2;0;215;255m-\033[38;2;0;135;255m-\033[38;2;0;54;255m-\033[38;2;26;0;255m-\033[38;2;107;0;255m-\033[38;2;187;0;255m-\033[38;2;255;0;242m-\033[38;2;255;0;162m-\033[38;2;255;0;81m-\033[38;2;255;0;0m-\033[0m"
read -p "Expired (minutes, 0 not allowed): " masaaktif
while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
    echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
    read -p "Expired (minutes, 0 not allowed): " masaaktif || exit 1
done

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
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
    \033[1;33mSSH Account\033[0m
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
Domain     : $domain
Username   : $username
Password   : $password
Expired    : $masaaktif Minutes
Limit IP   : 1
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
DNS        : 1.1.1.1 / 8.8.8.8
Pub Key    : $pub_key
Nameserver : $nameserver
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
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
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
OVPN WS     : 2086
OVPN TCP    : 1194
Config OVPN : http://${domain}/web/tcp.ovpn
\033[38;2;255;0;0m-\033[38;2;255;85;0m-\033[38;2;255;170;0m-\033[38;2;255;255;0m-\033[38;2;170;255;0m-\033[38;2;85;255;0m-\033[38;2;0;255;0m-\033[38;2;0;255;85m-\033[38;2;0;255;170m-\033[38;2;0;255;255m-\033[38;2;0;170;255m-\033[38;2;0;85;255m-\033[38;2;0;0;255m-\033[38;2;85;0;255m-\033[38;2;170;0;255m-\033[38;2;255;0;255m-\033[38;2;255;0;170m-\033[38;2;255;0;85m-\033[38;2;255;0;0m-\033[0m
EOF
)

# Kirim notifikasi ke Telegram
send_telegram_notification "$chat_id" "$key" "$message"

mkdir -p /var/log/create/ssh
echo "$message" > /var/log/create/ssh/${username}.log

clear
source /etc/funny/format.sh
format_display "$message"
