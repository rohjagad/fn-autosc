#!/bin/bash


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

domain=$(cat /etc/xray/domain)
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
    PERMISSION_DATA=$(curl -s --max-time 15 "$PERMISSION_PRIMARY" || curl -s --max-time 15 "$PERMISSION_FALLBACK" || { echo "Failed to download permissions."; exit 1; })

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep -wF "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP is not in the database"
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
        echo "Authorization has expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ($REMAINING_DAYS days)"; fi
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



function create() {
clear
until [[ $VPN_USER =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
		read -rp "Username : " -e VPN_USER || exit 0
		CLIENT_EXISTS=$(grep -w "$VPN_USER" /etc/funny/.l2tp | wc -l)

		if [[ ${CLIENT_EXISTS} -gt 0 ]]; then
			echo ""
			echo -e "Username ${red}${VPN_USER}${NC} already exists, please choose another"
			VPN_USER=""
			CLIENT_EXISTS=0
			continue
		fi
	done
read -p "Password : " VPN_PASSWORD || exit 0
[ -z "$VPN_PASSWORD" ] && exit 0
echo ""
echo -e "\033[38;5;208m0 not allowed\033[0m"
read -p "Duration (Days) : " masaaktif
while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
    echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
    read -p "Duration (Days) : " masaaktif || exit 1
done
hariini=`date -d "0 days" +"%Y-%m-%d"`
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
clear

# Add or update VPN user
cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF

VPN_PASSWORD_ENC=$(openssl passwd -1 "$VPN_PASSWORD")
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD_ENC:xauth-psk
EOF

# Update file attributes
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.l2tp 2>/dev/null || true
echo -e "### $VPN_USER $exp">>"/etc/funny/.l2tp"
systemctl daemon-reload
systemctl restart ipsec
systemctl restart xl2tpd
clear
PSK=$(grep -oP '(?<=: PSK ")\S+(?=")' /etc/ipsec.secrets 2>/dev/null || echo "myvpn")
cat <<EOF

============================
L2TP/IPSEC XAuth PSK VPN
============================
Domain     : $domain
IPsec PSK  : $PSK
Username   : $VPN_USER
Password   : $VPN_PASSWORD
Expired    : $exp
============================
EOF
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}


function delete() {
clear
clear
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/funny/.l2tp")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	echo ""
	echo " Select the existing client you want to remove"
	echo " Press CTRL+C to return"
	echo " ==============================="
	echo "     No  Expired   User"
	grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]] 2>/dev/null; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select One Client[1]: " CLIENT_NUMBER || exit 0
		else
			read -rp "Select One Client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER || exit 0
		fi
	done
# match the selected number to a client name
VPN_USER=$(grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
exp=$(grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
# Delete VPN user
sed -i '/^"'"$VPN_USER"'" l2tpd/d' /etc/ppp/chap-secrets
# shellcheck disable=SC2016
sed -i '/^'"$VPN_USER"':/d' /etc/ipsec.d/passwd
sed -i "/^### $VPN_USER $exp/d" /etc/funny/.l2tp
# Update file attributes
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.l2tp 2>/dev/null || true

systemctl daemon-reload
systemctl restart ipsec
systemctl restart xl2tpd
clear
echo ""
echo "=========================="
echo "   L2TP Account Deleted   "
echo "=========================="
echo "Username  : $VPN_USER"
echo "Expired   : $exp"
echo "=========================="
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

function extend() {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/funny/.l2tp")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear
	echo ""
	echo "Select the existing client you want to renew"
	echo " Press CTRL+C to return"
	echo -e "==============================="
	grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]] 2>/dev/null; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER || exit 0
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER || exit 0
		fi
	done
echo ""
echo -e "\033[38;5;208m0 not allowed\033[0m"
read -p "Expired (Days) : " masaaktif
while ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; do
    echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
    read -p "Expired (Days) : " masaaktif || exit 1
done
user=$(grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
exp=$(grep -E "^### " "/etc/funny/.l2tp" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo -e "\033[0;31mUnparseable expiry for this account - leaving it unchanged.\033[0m"
    sleep 2
    return
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if (( exp2 < 0 )); then
    exp2=0
fi
exp3=$(($exp2 + $masaaktif))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")
sed -i "s/^### $user $exp/### $user $exp4/" /etc/funny/.l2tp
chmod 600 /etc/funny/.l2tp 2>/dev/null || true
systemctl daemon-reload
systemctl restart ipsec
systemctl restart xl2tpd
clear
echo ""
echo "=========================="
echo "   L2TP Account Renewed   "
echo "=========================="
echo "Username  : $user"
echo "Expired   : $exp4"
echo "=========================="
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}


function main() {
clear
echo -e "${NC}${separator}
             L2TP MENU
${separator}
${green}1${NC}. Create L2TP Account
${green}2${NC}. Delete L2TP Account
${green}3${NC}. Extend L2TP Account
${green}4${NC}. Back to Main Menu
${green}5${NC}. Exit
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " menu || exit 0
echo -e ""
case $menu in
1)
create
main
;;
2)
delete
main
;;
3)
extend
main
;;
0|4)
clear
menu
;;
5)
clear
exit
;;
*)
clear
main
;;
esac
}

main
