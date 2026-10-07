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
echo ""
echo ""
# information
domain=$(cat /etc/xray/domain)
source /etc/wireguard/params
CLOUDFLAREKEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";

# Color
N="\033[0m"
R="\033[31m"
G="\033[32m"
B="\033[34m"
Y="\033[33m"
C="\033[36m"
M="\033[35m"
LR="\033[1;31m"
LG="\033[1;32m"
LB="\033[1;34m"
RB="\033[41;37m"
GB="\033[42;37m"
BB="\033[44;37m"
orange='\033[38;5;208m'
green='\033[0;32m'
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
blue_sep="\033[1;34m-----------------------------------\033[0m"

# Notification
OK="${G}[OK]${N}"
ERROR="${R}[ERROR]${N}"
INFO="${C}[+]${N}"

ok() {
  echo -e "${OK} ${G}$1${N}"
}

error() {
  echo -e "${ERROR} ${R}$1${N}"
}

info() {
  echo -e "${INFO} ${B}$1${N}"
}

newline() {
  echo -e ""
}

goback() {
  echo -e "Press any key to return \c" 
	read back
	main
}

function create() {
	endpoint="${ip}:51820"

	clear
	echo ""
	echo ""
	echo -e "Create WireGuard Account"
	echo -e "${separator}"
	echo -e " Username: \c"
	read user || exit 0
	while ! [[ "$user" =~ ^[a-zA-Z0-9_]+$ ]]; do
		[ -z "$user" ] && exit 0
		newline
		error "Username can only contain letters, numbers, and underscores"
		echo -e " Username: \c"
		read user || exit 0
	done
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		newline
		error "$user already exists"
		newline
		goback
		return
	fi
	echo ""
	echo -e "\033[38;5;208m0 not allowed\033[0m"
	echo -e " Duration (Days): \c"
	read duration
	while ! [[ "$duration" =~ ^[1-9][0-9]*$ ]]; do
		echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
		echo -e " Duration (Days): \c"
		read duration || exit 1
	done
	exp=$(date -d +${duration}days +%Y-%m-%d)
	expired=$(date -d "${exp}" +"%d-%b-%Y")

	for dot_ip in {2..254}; do
		dot_exists=$(grep -cF "10.66.66.${dot_ip}/" /etc/wireguard/wg0.conf)
		if [[ ${dot_exists} == '0' ]]; then
			break
		fi
	done
	if [[ ${dot_exists} -gt 0 ]]; then
		newline
		error "The subnet configured only supports 253 clients"
		newline
		goback
		return
	fi

	client_ipv4="10.66.66.${dot_ip}"
	client_priv_key=$(wg genkey)
	client_pub_key=$(echo "${client_priv_key}" | wg pubkey)
	client_pre_shared_key=$(wg genpsk)

	echo -e "$user\t$exp" >> /etc/funny/.wireguard
	echo -e "[Interface]
PrivateKey = ${client_priv_key}
Address = ${client_ipv4}/32
DNS = 8.8.8.8,8.8.4.4

[Peer]
PublicKey = ${server_pub_key}
PresharedKey = ${client_pre_shared_key}
Endpoint = ${endpoint}
AllowedIPs = 0.0.0.0/0" >> /var/www/html/wireguard-${user}.conf
	echo -e "\n### Client ${user}
[Peer]
PublicKey = ${client_pub_key}
PresharedKey = ${client_pre_shared_key}
AllowedIPs = ${client_ipv4}/32" >> /etc/wireguard/wg0.conf
	chmod 600 /etc/wireguard/wg0.conf 2>/dev/null || true
	systemctl daemon-reload
	systemctl restart wg-quick@wg0

	clear
	echo ""
	echo ""
	echo -e "WireGuard User Information"
	echo -e "${separator}"
	echo -e " Domain\t: $domain"
	echo -e " Username\t: $user"
	echo -e " Expired Date\t: $expired"
	echo -e "${blue_sep}"
        echo -e "Wireguard Detail"
	echo -e "Port Wireguard\t: 51820"
	echo -e "Private Key\t: ${client_priv_key}"
        echo -e "Publik Key\t: ${client_pub_key}"
	echo -e "${blue_sep}"
	echo -e "Link Config: http://${domain}/web/wireguard-${user}.conf"
        echo -e "${separator}"
	newline
	goback
}

function warp() {
source /etc/wireguard/params
#ip=$(curl -sS curl -sS ipv4.icanhazip.com)
clear
echo ""
echo ""
echo -n "Enter your generated PRIVATE KEY (leave blank to auto-generate): "
read PRIVATEKEY
echo -n "Enter your generated PUBLIC KEY (leave blank to auto-generate): "
read PUBLICKEY

if [ -z "$PRIVATEKEY" ]; then
    PRIVATEKEY=$(wg genkey)
    PUBLICKEY=$(echo "$PRIVATEKEY" | wg pubkey)
    echo "Generated PrivateKey: $PRIVATEKEY"
    echo "Generated PublicKey : $PUBLICKEY"
fi

echo ""
echo "This will take 3-5 minutes, wait until the process is finished..."
echo ""

curl --max-time 30 -d '{"key":"'$PUBLICKEY'", "install_id":"", "warp_enabled":true, "tos":"2019-11-17T00:00:00.000+01:00", "type":"Android", "locale":"en_GB"}' https://api.cloudflareclient.com/v0a2169/reg | tee warp.json > /dev/null
CLOUDFLAREKEY=$(jq -r '.config.peers[0].public_key // empty' warp.json 2>/dev/null)
if [ -z "$CLOUDFLAREKEY" ]; then
    echo "Failed to register with Cloudflare WARP API."
    rm -f warp.json
    goback
    return
fi
sudo wg set wg0 peer "$CLOUDFLAREKEY" endpoint engage.cloudflareclient.com:51820 allowed-ips 172.16.0.0/24 > out.log 2> /dev/null
wg-quick down wg0 > out.log 2> /dev/null
wg-quick up wg0 > out.log 2> /dev/null

clear
echo ""
echo ""
warpd=$(cat warp.json | jq .)

clear
echo ""
echo ""
echo 'Wireguard has successfully installed in your VPS

Your PUBLICKEY is '$PUBLICKEY'
Your PRIVATEKEY is '$PRIVATEKEY'

_______________________

Your Client Config is:

[Interface]
Address = 172.16.0.2/12
DNS = 1.1.1.1
PrivateKey = '$PRIVATEKEY'

[Peer]
PublicKey = '$CLOUDFLAREKEY'
AllowedIPs = 0.0.0.0/0
Endpoint = engage.cloudflareclient.com:2408

_______________________
'$warpd'
_______________________
'
rm -fr warp.json
}

function delete() {
	clear
	echo ""
	echo ""
	echo -e "Delete WireGuard User"
	echo -e "${separator}"
	echo -e " Username: \c"
	read user
	[ -z "$user" ] && { goback; return; }
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		awk "/^### Client ${user}$/{found=1} found && /^$/{found=0; next} !found{print} found{next}" \
			/etc/wireguard/wg0.conf > /tmp/wg0.conf && mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		chmod 600 /etc/wireguard/wg0.conf 2>/dev/null || true
		rm -f /var/www/html/wireguard-${user}.conf
		sed -i "/^$user[[:space:]]/d" /etc/funny/.wireguard
		systemctl daemon-reload
		systemctl restart wg-quick@wg0
		newline
		ok "$user deleted successfully"
		newline 
		goback
	else
		newline
		error "$user does not exist"
		newline 
		goback
	fi
}

function extend() {
	clear
	echo ""
	echo ""
	echo -e "Extend WireGuard User"
	echo -e "${separator}"
	echo -e " Username: \c"
	read user
	[ -z "$user" ] && { goback; return; }
	if ! grep -qw "$user" /etc/funny/.wireguard; then
		newline
		error "$user does not exist"
		newline
		goback
		return
	fi 
	echo ""
	echo -e "\033[38;5;208m0 not allowed\033[0m"
	echo -e " Duration (Days): \c"
	read extend
	while ! [[ "$extend" =~ ^[1-9][0-9]*$ ]]; do
		echo -e "\033[0;31mValue must be a whole number greater than 0.\033[0m"
		echo -e " Duration (Days): \c"
		read extend || exit 1
	done

	exp_old=$(grep -w "^$user" /etc/funny/.wireguard | awk '{print $2}' | head -n 1)
	d1_check=$(date -d "${exp_old}" +%s 2>/dev/null)
	if [ -z "$d1_check" ]; then
		echo -e "\033[0;31mUnparseable expiry for this account - leaving it unchanged.\033[0m"
		sleep 2
		goback
		return
	fi
	diff=$((($(date -d "${exp_old}" +%s)-$(date +%s))/(86400)))
	duration=$(expr $diff + $extend)
	exp_new=$(date -d +${duration}days +%Y-%m-%d)
	exp=$(date -d "${exp_new}" +"%d-%b-%Y")

	sed -i "/^$user[[:space:]]/d" /etc/funny/.wireguard
	echo -e "$user\t$exp_new" >> /etc/funny/.wireguard

	clear
	echo ""
	echo ""
	echo -e "WireGuard User Information"
	echo -e "${separator}"
	echo -e " Username\t: $user"
	echo -e " Expired Date\t: $exp"
	newline 
	goback
}

function list() {
	clear
	echo ""
	echo ""
	echo -e "${separator}"
	echo -e "Username          Exp. Date"
	echo -e "${blue_sep}"
	while read expired
	do
		user=$(echo $expired | awk '{print $1}')
		exp=$(echo $expired | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		printf "%-17s %2s\n" "$user" "$exp_date"
	done < /etc/funny/.wireguard
	total=$(wc -l /etc/funny/.wireguard | awk '{print $1}')
	echo -e "${blue_sep}"
	echo -e "Total Accounts: $total     "
	echo -e "${separator}"
	newline
	goback
}

function show() {
	clear
	echo ""
	echo ""
	echo -e "WireGuard Configuration"
	echo -e "${separator}"
	echo -e " Username\t: \c"
	read user
	[ -z "$user" ] && { goback; return; }
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		exp=$(cat /etc/funny/.wireguard | grep -w "$user" | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		echo -e " Expired\t: $exp_date"
		newline
		qrencode -t ansiutf8 -l L < /var/www/html/wireguard-${user}.conf
		newline
		echo -e "Configuration"
		echo -e "${separator}"
		newline
		cat /var/www/html/wireguard-${user}.conf
		newline 
		goback
	else
		newline
		error "$user does not exist"
		newline
		goback
	fi
}

function main() {
clear
echo ""
echo ""
echo -e "${NC}${separator}
          WIREGUARD MENU
${separator}
${green}1${NC}. Create WireGuard Account
${green}2${NC}. Delete WireGuard Account
${green}3${NC}. Extend WireGuard Account
${green}4${NC}. List WireGuard Accounts
${green}5${NC}. Show WireGuard Config
${green}6${NC}. Add Cloudflare WARP
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " menu || exit 0
case $menu in
1)
	create
	;;
2)
	delete 
	;;
3)
	extend 
	;;
4)
	list 
	;;
5)
	show 
	;;
6)
	warp
	;;
0|00|7)
	clear
	echo ""
	echo ""
	menu
	;;
*) 
	clear 
	echo ""
	echo ""
	error "Invalid option"
	sleep 1
	main
	;;
esac
}

main
