#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

# Konfigurasi URL izin
PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
LOCAL_IP=$(curl -4 -s ifconfig.me) # Mendapatkan IP lokal

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
    users=$(grep '^###' /etc/xray/json/ws.json | cut -d ' ' -f 2 | sort | uniq)

    for user in $users; do
        # Ambil statistik penggunaan dari Xray API (raw bytes). Bug 99: the
        # migration kept V2Ray's `api stats` call, but Xray's `stats` needs an
        # explicit -name and errors without one, so use the same statsquery +
        # inb/outb + reset pattern as quota-grpc/http/split.
        usage_data=$(xray api statsquery --server=127.0.0.1:10080 | grep -C 2 "$user" | grep value | awk '{print $2}' | sed 's/,//g; s/"//g')
        inb=$(echo "$usage_data" | sed -n 1p)
        outb=$(echo "$usage_data" | sed -n 2p)

        # Validasi data inb dan outb
        if [[ -z "$inb" || -z "$outb" ]]; then
            echo "Data usage for user $user is incomplete. Skipping."
            continue
        fi

        quota_used=$((inb + outb))

        usage_file="/etc/xray/quota/ws/${user}_usage"
        quota_file="/etc/xray/quota/ws/${user}"

        if [ -f "$usage_file" ]; then
            previous_usage=$(cat "$usage_file")
            quota_used=$((quota_used + previous_usage))
        fi

        echo "$quota_used" > "$usage_file"

        if [[ -f "$quota_file" ]]; then
        quota_limit=$(cat "$quota_file")
        if [[ "$quota_used" -gt "$quota_limit" ]]; then
            exp=$(grep -w "^### $user" "/etc/xray/json/ws.json" | awk '{print $3}' | sort -u)
            sed -i "/### $user $exp/ {N;d}" /etc/xray/json/ws.json
            sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
            total_usage=$(con "$quota_used")
            total_limit=$(con "$quota_limit")
            send_log
            rm -f "$usage_file" "$quota_file"
            systemctl restart xray@ws
            echo "User $user reached quota limit and has been locked."
        fi
        fi

        # Reset statistik supaya pass berikutnya membaca delta, bukan total
        xray api stats --server=127.0.0.1:10080 -name "user>>>${user}>>>traffic>>>downlink" -reset >/dev/null 2>&1
        xray api stats --server=127.0.0.1:10080 -name "user>>>${user}>>>traffic>>>uplink" -reset >/dev/null 2>&1
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