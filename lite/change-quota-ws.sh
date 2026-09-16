#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohfn-autosc-auth/1.23/izin.txt"
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

# Warna
yellow="\033[0;33m"
ungu="\033[0;35m"
Red="\033[91;1m"
Cyan="\033[96;1m"
Xark="\033[0m"
BlueCyan="\033[5;36m"
WhiteBe="\033[5;37m"
GreenBe="\033[5;32m"
YellowBe="\033[5;33m"
BlueBe="\033[5;34m"

# Notifikasi
function send_log() {
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
TEXT="
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>QUOTA WEBSOCKET ACOUNT</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Username    :</b> <code>$user</code>
<b>Date        :</b> <code>$DATE</code>
<b>Old Limit   :</b> <code>${old_quota} GB</code>
<b>New Limit   :</b> <code>${new_quota} GB</code>
<b>Quota Usage :</b> <code>${quota_status}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━</b>
<i>Note:</i> The Xray account quota limit has been successfully updated in the server database."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

# Garis Panjang Old
function baris_panjang() {
  echo -e "${BlueCyan} ——————————————————————————————————— ${Xark} "
}

# Banner
function FN_Banner() {
  clear
  baris_panjang
  echo -e "${ungu}            FN PROJECT      ${Xark} "
  baris_panjang
}

# Kredit
function Sc_Credit(){
  sleep 1
  baris_panjang
  echo -e "${ungu}    Terimakasih Telah Menggunakan ${Xark}"
  echo -e "${ungu}             Script  Credit ${Xark}"
  echo -e "${ungu}               FN PROJECT ${Xark}"
  baris_panjang
  exit 1
}

# Animasi Loading
duration=6
frames=("██10%" "█████35%" "█████████65%" "█████████████80%" "█████████████████████90%" "█████████████████████████100%")
num_frames=${#frames[@]}
num_iterations=$((duration))

Loading_Animasi() {
  for ((i = 0; i < num_iterations; i++)); do
    clear
    index=$((i % num_frames))
    color_code=$((31 + i % 7))
    echo ""
    echo ""
    echo ""
    echo -e "\e[1;${color_code}m ${frames[$index]}\e[0m"
    sleep 0.5
  done
}

# Sukses setelah Loading
function Loading_Succes() {
  clear
  echo -e "\033[5;32mSucces\033[0m"
  sleep 1
  clear
}

# Daftar Akun
function Daftar_Account() {
    # Header tabel
    printf "${Cyan} %-20s %-15s %-10s ${Xark}\n" "Username" "Expired" "Limit Quota (GB)"
    baris_panjang

    # Loop melalui semua file log yang relevan
    for file in /var/log/create/xray/ws/*.log; do
        if [[ -f "$file" ]]; then
            username=$(basename "$file" .log)
            expired=$(grep "Expired :" "$file" | awk -F': ' '{print $2}')
            limit_quota=$(grep "Quota" "$file" | awk '{print $3}')

            # Jika tidak ditemukan, set nilai default
            expired=${expired:-"N/A"}
            limit_quota=${limit_quota:-"N/A"}

            # Tampilkan data dengan format terstruktur
            printf "${ungu} %-20s %-15s %-10s ${Xark}\n" "$username" "$expired" "$limit_quota"
        fi
    done
}

# Fungsi untuk Mengganti Kuota
function change_quota() {
    FN_Banner
    Daftar_Account
    baris_panjang
    echo ""
    read -p " Input Username        :   " user

    quota_file="/etc/xray/quota/ws/${user}"
    log_file="/var/log/create/xray/ws/${user}.log"

    # Validasi apakah file kuota ada
    if [[ -e "$quota_file" && -e "$log_file" ]]; then
        current_quota=$(cat "$quota_file")
        old_quota=$(grep "Quota" "$log_file" | awk '{print $3}')
        echo ""
        echo ""
        baris_panjang
        echo -e "${Cyan} BEFORE QUOTA ${Xark}"
        echo -e ""
        echo -e "${GreenBe} Quota      : $((current_quota / 1024 / 1024 / 1024)) GB ${Xark}"
        echo -e "${GreenBe} Username   : $user ${Xark}"
        echo -e ""
        baris_panjang
        echo ""
        read -p " Input New Quota (GB) : " new_quota
        echo -e "\n${YellowBe}Reset total usage quota? (y/n):${Xark}"
        read -rp "Input: " reset_quota
        if [[ $reset_quota == "y" || $reset_quota == "Y" ]]; then
            echo -n > /etc/xray/quota/ws/${user}_usage
            quota_status="Reset"
        else
            quota_status="No"
        fi
        systemctl daemon-reload
        systemctl restart v2ray
        systemctl restart quota-ws
        Loading_Animasi
        Loading_Succes

        # Validasi jika input kuota kosong atau tidak valid
        if [[ -z "$new_quota" || ! "$new_quota" =~ ^[0-9]+$ ]]; then
            echo -e "${Red} Invalid quota input. No changes made. ${Xark}"
            return 1
        else
            # Konversi kuota baru ke byte
            new_quota_bytes=$((new_quota * 1024 * 1024 * 1024))
            echo "${new_quota_bytes}" > "${quota_file}"

            # Perbarui kuota di dalam file log
            sed -i "s/Quota   : ${old_quota} GB/Quota   : ${new_quota} GB/" "$log_file"

            FN_Banner
            echo -e "${GreenBe} Successfully updated quota ${Xark}"
            echo ""
            echo -e "${Cyan} AFTER ${Xark}"
            echo ""
            printf "${yellow} %-20s %-15s %-10s ${Xark}\n" "Username" "Quota (GB)" "Status"
            printf "${ungu} %-20s %-15s %-10s ${Xark}\n" "$user" "$new_quota" "$quota_status"
            echo ""
 #           baris_panjang
	    send_log
            Sc_Credit
        fi
    else
        FN_Banner
        echo ""
        echo -e "${Red} Error: Invalid username or quota file does not exist. ${Xark}"
        echo ""
#        baris_panjang
        Sc_Credit
    fi
}

# Panggil Fungsi Ganti Kuota
change_quota
