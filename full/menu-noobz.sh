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

domain=$(cat /etc/xray/domain)

clear

function create() {
clear
echo -e "
════════════════════════════
Add Account NoobzVPN
════════════════════════════"
read -p "Username  : " user
read -p "Password  : " pass
read -p "Masa Aktif: " masaaktif
clear
noobzvpns --add-user "$user" "$pass"
noobzvpns --expired-user "$user" "$masaaktif"
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
Delete Account
════════════════════════════
$mna
════════════════════════════
"
read -p "Input Name: " name
if [ -z $name ]; then
menu
else
exp=$(grep -we "^### $user" "/etc/noobzvpns/.noob" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^### $user $exp/,/^},{/d" /etc/noobzvpns/.noob
noobzvpns --remove-user "$name"
clear
TEKS="
════════════════════════════
Username Delete
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
# Menjalankan perintah noobzvpns --info-all-user dan menyimpan hasilnya
output=$(noobzvpns --info-all-user)

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
  echo -e "\033[1;34m│       Informatiom Account NoobzVPN       │\033[0m"
  echo -e "\033[1;34m╰──────────────────────────────────────────╯\033[0m"  

  while IFS= read -r line; do
    if [[ $line == +* ]]; then
      echo -e "\033[1;32mStatus : Aktif\033[0m" # Hijau untuk status aktif
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
      echo -e "\033[1;35m Total Pengguna : $total\033[0m" # Ungu untuk Total Users
    fi
  done <<< "$1"

  echo -e "\033[1;34m╭──────────────────────────────────────────╮\033[0m"
  echo -e "\033[1;34m│           Akhir Informasi                │\033[0m"
  echo -e "\033[1;34m╰──────────────────────────────────────────╯\033[0m"
}

# Panggil fungsi format_output dengan output dari noobzvpns sebagai argumen
clear
format_output "$output"
}

function main() {
white='\e[037;1m'
RED='\e[31m'
GREEN='\e[32m'
NC='\033[0;37m'
domain=$(cat /etc/xray/domain)
clear
if [[ $(systemctl status noobzvpns | grep -w Active | awk '{print $2}' | sed 's/(//g' | sed 's/)//g' | sed 's/ //g') == 'active' ]]; then
    status="${GREEN}ON${NC}";
else
    status="${RED}OFF${NC}";
fi
clear
echo -e "════════════════════════════════"
echo -e "${GREEN}[ ${RED}<== ${white}NOOBZVPN STORE『EA』 ${RED}==> ${GREEN}]"
echo "════════════════════════════════"
echo -e "Noobz: $status
${white}

1. Add Account
2. Delete Account
3. List Active Account"
echo "════════════════════════════════"
echo "Preess CTRL or X to exit"
echo "════════════════════════════════"
read -p "Input Option: " inrere
case $inrere in
1|01) clear ; create ;;
2|02) clear ; delete ;;
3|03) clear ; list ;;
x|X) exit ;;
*) echo "Wrong Number " ; main ;;
esac
}

main
