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
        echo "Invalid expiration date."
        exit 1
    fi
    echo $(( (expired_date - today) / 86400 ))
}

# Unduh izin dan validasi
clear
PERMISSION_DATA=$(curl -s "$PERMISSION_URL" || { echo "Failed to download permissions."; exit 1; })

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
    echo "Permission expired."
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

# Fungsi untuk mengirim log ke Telegram
send_log() {
    CHATID=$(cat /etc/funny/.chatid)
    KEY=$(cat /etc/funny/.keybot)
    URL="https://api.telegram.org/bot${KEY}/sendMessage"

    TEXT="
<code>────────────────────</code>
<b> NOTIF QUOTA WebSocket HABIS</b>
<code>────────────────────</code>
<code>Username  : </code><code>${user}</code>
<code>Usage     : </code><code>${total_usage}</code>
<code>Limit     : </code><code>${total_limit}</code>
<code>Status    : </code><code>Deleted</code>
<code>────────────────────</code>
"
    curl -s -X POST "$URL" -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=html" >/dev/null
}

# Fungsi untuk mengonversi byte ke format manusiawi
con() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.2f KB\n" "$(bc -l <<< "scale=2; $bytes/1024")"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.2f MB\n" "$(bc -l <<< "scale=2; $bytes/1048576")"
    elif [[ $bytes -lt 1099511627776 ]]; then
        printf "%.2f GB\n" "$(bc -l <<< "scale=2; $bytes/1073741824")"
    else
        printf "%.2f TB\n" "$(bc -l <<< "scale=2; $bytes/1099511627776")"
    fi
}

# Fungsi untuk memeriksa penggunaan ws
cekws() {
    users=$(grep '^###' /etc/v2ray/config.json | cut -d ' ' -f 2 | sort | uniq)

    for user in $users; do
        # Ambil statistik penggunaan dari V2Ray API
        usage_data=$(v2ray api stats --server=127.0.0.1:10080 | grep "user>>>${user}>>>traffic" | awk '{print $2}')
        inb=$(echo "$usage_data" | sed -n 1p | sed 's/MB//')

        # Validasi data inb
        if [[ -z "$inb" ]]; then
            echo "Data inbound usage for user $user is incomplete. Skipping."
            continue
        fi

        inb_bytes=$(echo "$inb * 1048576" | bc)
        quota_used=$inb_bytes

        usage_file="/etc/xray/quota/ws/${user}_usage"
        quota_file="/etc/xray/quota/ws/${user}"

        if [ -f "$usage_file" ]; then
            previous_usage=$(cat "$usage_file")
            quota_used=$(echo "$quota_used + $previous_usage" | bc)
        fi

        # Hapus titik dan angka desimal
        quota_used=$(echo "$quota_used" | cut -d '.' -f 1)

        echo "$quota_used" > "$usage_file"

        quota_limit=$(cat "$quota_file")
        if (( $(echo "$quota_used > $quota_limit" | bc -l) )); then
            exp=$(grep -w "^### $user" "/etc/v2ray/config.json" | awk '{print $3}')
            sed -i "/### $user $exp/ {N;d}" /etc/v2ray/config.json
            total_usage=$(con "$quota_used")
            total_limit=$(con "$quota_limit")
            send_log
            rm -f "$usage_file" "$quota_file"
            systemctl restart v2ray
            echo "User $user reached quota limit and has been locked."
        fi
    done
}

# Fungsi utama untuk memonitor ws secara terus-menerus
ws() {
    while true; do
        sleep 30
        cekws
    done
}

# Eksekusi fungsi utama
ws