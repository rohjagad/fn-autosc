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
        echo "Your IP is not in the database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    if [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"
    }

clear

red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
NC='\033[0m'

rainbow_sep() {
  local text="${1:-===================================}"
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

separator=$(rainbow_sep '===================================')
blue_sep="${blue}-----------------------------------${NC}"

domain=$(cat /etc/xray/domain)

clear

noobz_add_user() {
    local u="$1" p="$2" e="$3"
    if noobzvpns add --help >/dev/null 2>&1; then
        noobzvpns add --password "$p" --expired "$e" "$u"
    else
        noobzvpns --add-user "$u" "$p"
        noobzvpns --expired-user "$u" "$e"
    fi
}

noobz_remove_user() {
    local u="$1"
    if noobzvpns remove --help >/dev/null 2>&1; then
        noobzvpns remove "$u"
    else
        noobzvpns --remove-user "$u"
    fi
}

noobz_list_users() {
    if noobzvpns print-all >/dev/null 2>&1; then
        noobzvpns print-all
    else
        noobzvpns --info-all-user
    fi
}

function create() {
clear
echo -e "
════════════════════════════
Create NoobzVPN Account
════════════════════════════"
read -p "Username  : " user
read -p "Password  : " pass
read -p "Duration (Days): " masaaktif
clear
noobz_add_user "$user" "$pass" "$masaaktif"
expi=`date -d "$masaaktif days" +"%Y-%m-%d"`
echo "### ${user} ${expi}" >>/etc/noobzvpns/.noob
clear
TEKS="
════════════════════════════
NoobzVPN Account
════════════════════════════
Hostname  : $domain
Username  : $user
Password  : $pass
════════════════════════════
TCP_STD/HTTP  : 8080
TCP_SSL/HTTPS : 8443
════════════════════════════
PAYLOAD   : GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]
════════════════════════════
Expired   : $expi
════════════════════════════"
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME -d "chat_id=$CHATID&text=$TEKS" $URL
clear
echo "$TEKS"
}

function delete() {
mna=$(grep -e "^### " "/etc/noobzvpns/.noob" | cut -d ' ' -f 2-3 | column -t | sort | uniq)
clear
echo -e "
════════════════════════════
Delete NoobzVPN Account
════════════════════════════
$mna
════════════════════════════
"
read -p "Username: " name
if [ -z $name ]; then
menu
else
exp=$(grep -we "^### $name" "/etc/noobzvpns/.noob" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^### $name $exp/d" /etc/noobzvpns/.noob
noobz_remove_user "$name"
clear
TEKS="
════════════════════════════
Account Deleted
════════════════════════════

User: $name
Exp : $exp
════════════════════════════
"
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME -d "chat_id=$CHATID&text=$TEKS" $URL
clear
echo "$TEKS"
fi
}

function list() {
# Menjalankan perintah list user dan menyimpan hasilnya
output=$(noobz_list_users)

# Fungsi untuk memformat tanggal issued menjadi lebih mudah dibaca
format_issued() {
  local issued_date="$1"
  
  # Mengonversi tanggal issued menjadi format YYYY-MM-DD
  local year="${issued_date:0:4}"
  local month="${issued_date:4:2}"
  local day="${issued_date:6:2}"

  # Format ulang tanggal menjadi YYYY-MM-DD
  echo "$year-$month-$day"
}

# Fungsi untuk memformat output dengan lebih rapi
format_output() {
  echo -e "\033[1;34m╭──────────────────────────────────────────╮\033[0m"
  echo -e "\033[1;34m│         NoobzVPN Account Details         │\033[0m"
  echo -e "\033[1;34m╰──────────────────────────────────────────╯\033[0m"  

  while IFS= read -r line; do
    if [[ $line == +* ]]; then
      echo -e "\033[1;32mStatus : Active\033[0m" # Hijau untuk status aktif
    elif [[ $line == *blocked:* ]]; then
      status=${line/*blocked:/}
      echo -e "  \033[1;33mBlocked :\033[0m \033[1;31m$status\033[0m" # Merah untuk blocked
    elif [[ $line == *hash_key:* ]]; then
      hash=${line/*hash_key:/}
      echo -e "  \033[1;36mHash Key :\033[0m $hash" # Cyan untuk hash_key
    elif [[ $line == *issued* ]]; then
      issued=${line/*issued(yyyymmdd):/}
      formatted_issued=$(format_issued "$issued")
      echo -e "  \033[1;33mIssued (YYYYMMDD) :\033[0m $formatted_issued" # Kuning untuk issued
    elif [[ $line == *expired:* ]]; then
      expired_info=${line/*expired:/}
      echo -e "  \033[1;34mExpired :\033[0m $expired_info" # Biru untuk expired
    elif [[ $line == Total* ]]; then
      total=${line/*Total User(s):/}
      echo -e "\033[1;35m Total Users : $total\033[0m" # Ungu untuk Total Users
    fi
  done <<< "$1"

  echo -e "\033[1;34m╭──────────────────────────────────────────╮\033[0m"
  echo -e "\033[1;34m│         End of Account Details           │\033[0m"
  echo -e "\033[1;34m╰──────────────────────────────────────────╯\033[0m"
}

# Panggil fungsi format_output dengan output dari noobzvpns sebagai argumen
clear
format_output "$output"
}

function main() {
if [[ $(systemctl status noobzvpns 2>/dev/null | grep -w Active | awk '{print $2}' | sed 's/(//g' | sed 's/)//g' | sed 's/ //g') == 'active' ]]; then
    status="${green}ON${NC}"
else
    status="${red}OFF${NC}"
fi
clear
echo -e "${NC}${separator}
           NOOBZVPN MENU
${separator}
Noobz        : $status
${blue_sep}
${green}1${NC}. Create Account
${green}2${NC}. Delete Account
${green}3${NC}. List Active Accounts
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " inrere
case $inrere in
1|01) clear ; create ;;
2|02) clear ; delete ;;
3|03) clear ; list ;;
x|X) exit ;;
*) echo "Invalid option" ; main ;;
esac
}

main
