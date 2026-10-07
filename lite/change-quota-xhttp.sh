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
# Warna
yellow="\033[0;33m"
ungu="\033[0;35m"
Red="\033[91;1m"
Cyan="\033[96;1m"
Xark="\033[0m"
blue='\033[1;34m'
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

BlueCyan="\033[5;36m"
WhiteBe="\033[5;37m"
GreenBe="\033[5;32m"
YellowBe="\033[5;33m"
BlueBe="\033[5;34m"

# Notifikasi
function send_log() {
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%d-%b-%Y %H:%M:%S")
TEXT="
<b>-----------------------</b>
<b>QUOTA XHTTP ACCOUNT</b>
<b>-----------------------</b>
<code>Username    : $user</code>
<code>Date        : $DATE</code>
<code>Old Limit   : ${old_quota} GB</code>
<code>New Limit   : ${new_quota} GB</code>
<code>Quota Usage : ${quota_status}</code>
<b>-----------------------</b>
<i>Note:</i> The Xray account quota limit has been successfully updated in the server database."
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}

# Garis Panjang Old
function baris_panjang() {
  echo -e "${separator}"
}

# Banner
function FN_Banner() {
  clear
  echo ""
  echo ""
  echo ""
  echo -e "${separator}"
  echo -e "   Change Quota XHTTP"
  echo -e "${separator}"
}

# Animasi Loading
duration=6
frames=("██10%" "█████35%" "█████████65%" "█████████████80%" "█████████████████████90%" "█████████████████████████100%")
num_frames=${#frames[@]}
num_iterations=$((duration))

Loading_Animasi() {
  for ((i = 0; i < num_iterations; i++)); do
    clear
    echo ""
    echo ""
    echo ""
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
  echo ""
  echo ""
  echo ""
  echo -e "\033[5;32mSucces\033[0m"
  sleep 1
  clear
  echo ""
  echo ""
  echo ""
}

# Daftar Akun
function Daftar_Account() {
    users=( $(ls /var/log/create/xray/xhttp/ 2>/dev/null | sed -E 's/\.log$'// | sort -u) )
    if [ ${#users[@]} -eq 0 ]; then
        echo "No active accounts found."
        echo -e "${separator}"
        return 1
    fi
    local i=1 u q
    for u in "${users[@]}"; do
        q=$(grep "Quota" "/var/log/create/xray/xhttp/${u}.log" 2>/dev/null | awk '{print $3, $4}')
        printf "\e[32;1m%02d\e[0m. %-20s %s\n" "$i" "$u" "${q:-N/A}"
        i=$((i+1))
    done
    echo -e "${blue_sep}"
    echo -e "Total Accounts: ${#users[@]}"
    echo -e "${blue_sep}"
    echo -e "\033[38;5;208mPress [Ctrl + C] to exit\033[0m"
}

# Fungsi untuk Mengganti Kuota
function change_quota() {
    FN_Banner
    Daftar_Account || return
    echo -e "${separator}"
    echo ""
    read -p " Input Username: " input || return
    user="$input"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        n=$((10#$input))
        if [ "$n" -ge 1 ] && [ "$n" -le "${#users[@]}" ]; then
            user="${users[$((n-1))]}"
        fi
    fi

    quota_file="/etc/xray/quota/xhttp/${user}"
    log_file="/var/log/create/xray/xhttp/${user}.log"

    # Validasi apakah file kuota ada
    if [[ -e "$quota_file" && -e "$log_file" ]]; then
        current_quota=$(cat "$quota_file")
        old_quota=$(grep "Quota" "$log_file" | awk '{print $3}')
        echo ""
        echo ""
        echo -e "${separator}"
        echo -e "${Cyan} BEFORE QUOTA ${Xark}"
        echo -e ""
        echo -e "${GreenBe} Quota      : $((current_quota / 1024 / 1024 / 1024)) GB ${Xark}"
        echo -e "${GreenBe} Username   : $user ${Xark}"
        echo -e ""
        echo -e "${separator}"
        echo ""
        echo ""
        echo -e "\033[38;5;208m0 not allowed\033[0m"
        read -p " Input New Quota (GBs) : " new_quota
        while ! [[ "$new_quota" =~ ^[1-9][0-9]*$ ]]; do
            echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
            read -p " Input New Quota (GBs) : " new_quota || exit 1
        done
        echo -e "\n${YellowBe}Reset total usage quota? (y/n):${Xark}"
        read -rp "Input: " reset_quota
        if [[ $reset_quota == "y" || $reset_quota == "Y" ]]; then
            > /etc/xray/quota/xhttp/${user}_usage
            quota_status="Reset"
        else
            quota_status="No"
        fi
        # Konversi kuota baru ke byte (write before restart so services read new value)
        new_quota_bytes=$((new_quota * 1024 * 1024 * 1024))
        echo "${new_quota_bytes}" > "${quota_file}"

        # Perbarui kuota di dalam file log
        sed -i "s/Quota   : ${old_quota} GB/Quota   : ${new_quota} GB/" "$log_file"

        if xray run -test -config /etc/xray/json/xhttp.json >/dev/null 2>&1; then
            systemctl daemon-reload
            systemctl restart xray@xhttp
            systemctl restart quota-xhttp
        fi
        Loading_Animasi
        Loading_Succes

            FN_Banner
            echo -e "${GreenBe} Successfully updated quota ${Xark}"
            echo ""
            echo -e "${Cyan} AFTER ${Xark}"
            echo ""
            printf "${yellow} %-20s %-15s %-10s ${Xark}\n" "Username" "Quota (GB)" "Status"
            echo -e "${blue_sep}"
            printf "${ungu} %-20s %-15s %-10s ${Xark}\n" "$user" "$new_quota" "$quota_status"
            echo -e "${separator}"
            echo ""
 #           baris_panjang
	    send_log
            exit 0
    else
        FN_Banner
        echo ""
        echo -e "${Red} Error: Invalid username or quota file does not exist. ${Xark}"
        echo ""
#        baris_panjang
        exit 0
    fi
}

# Panggil Fungsi Ganti Kuota
change_quota
