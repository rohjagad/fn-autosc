#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohtunnel-autosc-auth/main/izin.txt"
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

# Function Bytes Quota
function bytes() {
    local -i bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( (bytes + 1023) / 1024 )) KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( (bytes + 1048575) / 1048576 )) MB"
    elif [[ $bytes -lt 1099511627776 ]]; then
        echo "$(( (bytes + 1073741823) / 1073741824 )) GB"
    elif [[ $bytes -lt 1125899906842624 ]]; then
        echo "$(( (bytes + 1099511627775) / 1099511627776 )) TB"
    elif [[ $bytes -lt 1152921504606846976 ]]; then
        echo "$(( (bytes + 1125899906842623) / 1125899906842624 )) PB"
    else
        echo "$(( (bytes + 1152921504606846975) / 1152921504606846976 )) EB"
    fi
}

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "=[ Member XTLS WebSocket Account ]=         "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -n > /var/log/xray/accsess.log
> /root/.system

# Mendapatkan daftar username tanpa duplikasi dan hanya memperhitungkan status
data=( $(ls /var/log/create/xray/ws/ | sed -E 's/\.(locked|log)$//' | sort -u) )

# Mengecek setiap user
for user in "${data[@]}"
do
    # Mengecek status berdasarkan ekstensi file
    if [[ -f /var/log/create/xray/ws/${user}.locked ]]; then
        status="locked"
    elif [[ -f /var/log/create/xray/ws/${user}.log ]]; then
        status="unlocked"
    else
        status="unknown"
    fi

    # Menampilkan informasi untuk status locked
    if [[ "$status" == "locked" ]]; then
        echo -e "\e[33;1mUser\e[32;1m: $user"
        echo -e "\e[33;1mStatus Account X-Ray\e[32;1m: $status"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "@Rerechan02" >> /root/.system
    fi

    # Menampilkan informasi untuk status unlocked (hanya jika status unlocked)
    if [[ "$status" == "unlocked" ]]; then
        limip=$(grep "Limit IP:" /var/log/create/xray/ws/${user}.log | awk '{print $3}')
        top=$(cat /etc/xray/quota/ws/${user} 2>/dev/null || echo 0)
        quota=$(bytes "$top")
        uid=$(grep "${user}" /etc/xray/json/ws.json | awk -F'"id": "' '{print $2}' | awk -F'"' '{print $1}' | sort | uniq | strings)
        protokol=$(grep "Protokol:" /var/log/create/xray/ws/${user}.log | awk '{print $2}')
        exp=$(grep "Expired" /var/log/create/xray/ws/${user}.log | awk '{print $3}')
        
        # Menampilkan informasi akun unlocked
        echo -e "\e[33;1mUser\e[32;1m: $user"
        echo -e "\e[33;1mExpired\e[32;1m: $exp"
        echo -e "\e[33;1mLimit IP\e[32;1m: $limip"
        echo -e "\e[33;1mLimit Quota\e[32;1m: $quota"
        echo -e "\e[33;1mUUID / Password\e[32;1m: $uid"
        echo -e "\e[33;1mProtocol Account\e[32;1m: $protokol"
        echo -e "\e[33;1mStatus Account X-Ray\e[32;1m: $status"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "@Rerechan02" >> /root/.system
    fi
    sleep 0.1
done

# Menampilkan jumlah pengguna aktif
aktif=$(wc -l < /root/.system)
echo -e "$aktif Member Active"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
> /root/.system