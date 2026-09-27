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

bnnr() {
read -p "Input Your Banner: " bns || return
echo -e "$bns" > /etc/issue.net
systemctl daemon-reload
systemctl restart ws 2>/dev/null || true
clear
echo -e "
=====================
Success Change Banner
=====================
"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

resall() {
clear
echo -e "Start Restart All Service"
systemctl daemon-reload
systemctl restart ssh
systemctl restart sshd 2>/dev/null || true
systemctl restart cron
systemctl restart xray@ws
systemctl restart xray@upgrade
systemctl restart xray@split
systemctl restart xray@grpc
systemctl restart quota-ws
systemctl restart quota-http
systemctl restart quota-split
systemctl restart quota-grpc
systemctl restart nginx
clear
echo -e "
\n
Success Restart All Service Server\n\n"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}

menu-warp() {
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Red_font_prefix}[information]${Font_color_suffix}"

clear

install() {
clear
    # Date-licensed machines must not bring WARP up: it moves egress through
    # Cloudflare, the licence gate then sees an unlisted IP and the whole
    # panel locks out (Found 168). Only "lifetime" entries may use WARP
    # (is-decision.md 28). $EXPIRED_DATE comes from the gate above.
    if [ "$EXPIRED_DATE" != "lifetime" ]; then
        clear
        echo -e "WARP is not allowed on a date-licensed machine: it changes the server IP and would break the license check."
        return
    fi
# Check OS version
if [[ -e /etc/debian_version ]]; then
        source /etc/os-release
        OS=$ID # debian or ubuntu
elif [[ -e /etc/centos-release ]]; then
        source /etc/os-release
        OS=centos
fi
# Check OS version
if [[ -e /etc/debian_version ]]; then
        source /etc/os-release
        OS=$ID # debian or ubuntu
elif [[ -e /etc/centos-release ]]; then
        source /etc/os-release
        OS=centos
fi

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[information]${Font_color_suffix}"

# This used to abort when /etc/wireguard/params existed, but that file is
# written by installer/wg.sh. WARP is a separate WireGuard interface (wgcf),
# and the existing /usr/bin/warp.sh check below already handles
# re-installation.

# Install WireGuard tools and module
        if [[ $OS == 'ubuntu' ]]; then
        apt install -y wireguard
elif [[ $OS == 'debian' ]]; then
        # Debian 12 ships WireGuard in-tree. Only fall back to Debian unstable
        # plus the matching kernel headers when the running kernel has no
        # WireGuard module; doing it unconditionally installs a new kernel and
        # a large dependency set for nothing (observed on the test host:
        # linux-image-6.1.0-53 plus llvm and the media stack).
        if modinfo wireguard >/dev/null 2>&1 || grep -qw wireguard "/lib/modules/$(uname -r)/modules.builtin" 2>/dev/null; then
                apt install -y wireguard-tools iptables iptables-persistent
        else
                echo "deb http://deb.debian.org/debian/ unstable main" >/etc/apt/sources.list.d/unstable.list
                printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' >/etc/apt/preferences.d/limit-unstable
                apt update
                apt install -y wireguard-tools iptables iptables-persistent
                apt install -y linux-headers-$(uname -r)
        fi
elif [[ ${OS} == 'centos' ]]; then
        curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum -y update
        yum -y install wireguard-dkms wireguard-tools
        fi
apt install iptables iptables-persistent -y
# Make sure the directory exists (this does not seem the be the case on fedora)
mkdir -p /etc/wireguard >/dev/null 2>&1

# Install Warp
if [[ -e /usr/bin/warp.sh ]]; then
 echo -e "${Info} Warp already Install,."
else
cd /usr/bin
wget git.io/warp.sh
bash warp.sh install
bash warp.sh wgd
fi
chmod +x /usr/bin/warp.sh
clear
}

status() {
    clear
    if command -v warp.sh >/dev/null 2>&1 || [[ -x /usr/bin/warp.sh ]]; then
        /usr/bin/warp.sh status 2>/dev/null || warp.sh status 2>/dev/null || true
    else
        echo "WARP is not installed. Choose option 1 to install first."
    fi
    echo ""
    echo "Cloudflare Trace:"
    curl -s --max-time 10 https://www.cloudflare.com/cdn-cgi/trace
    echo ""
    read -n 1 -s -r -p "Press any key to return..." || true
}

enable() {
    # Date-licensed machines must not bring WARP up: it moves egress through
    # Cloudflare, the licence gate then sees an unlisted IP and the whole
    # panel locks out (Found 168). Only "lifetime" entries may use WARP
    # (is-decision.md 28). $EXPIRED_DATE comes from the gate above.
    if [ "$EXPIRED_DATE" != "lifetime" ]; then
        clear
        echo -e "WARP is not allowed on a date-licensed machine: it changes the server IP and would break the license check."
        read -n 1 -s -r -p "Press any key to return..." || true
        return
    fi
    # install() sets WARP up with P3TERX warp.sh ("warp.sh wgd"), i.e. the
    # wg-quick@wgcf interface, and restart() drives that same unit - so enable
    # must drive it too. warp-cli is not the control path here: on a warp.sh
    # install it has no registration, so connect/disconnect change nothing.
    systemctl enable --now wg-quick@wgcf >/dev/null 2>&1
    clear
    if ip link show wgcf >/dev/null 2>&1; then
        echo -e "Done Enable Warp"
    else
        echo -e "WARP is not running"
    fi
    read -n 1 -s -r -p "Press any key to return..." || true
}

disable() {
    systemctl disable --now wg-quick@wgcf >/dev/null 2>&1
    wg-quick down wgcf >/dev/null 2>&1
    clear
    if ip link show wgcf >/dev/null 2>&1; then
        echo -e "WARP is still running"
    else
        echo -e "success disable warp"
    fi
    read -n 1 -s -r -p "Press any key to return..." || true
}

restart() {
    # Same guard as install()/enable(): restarting would start an inactive
    # wgcf and move egress, breaking a date license the same way.
    if [ "$EXPIRED_DATE" != "lifetime" ]; then
        clear
        echo -e "WARP is not allowed on a date-licensed machine: it changes the server IP and would break the license check."
        read -n 1 -s -r -p "Press any key to return..." || true
        return
    fi
    warp.sh restart 2>/dev/null || true
    systemctl daemon-reload
    systemctl restart wg-quick@wgcf 2>/dev/null || true
    clear
    echo -e "Done Restart Service Warp Wireguard"
    read -n 1 -s -r -p "Press any key to return..." || true
}

akun4() {
    clear
    local conf=""
    if [[ -f /etc/wireguard/wgcf.conf ]]; then
        conf=$(cat /etc/wireguard/wgcf.conf)
    elif [[ -f /etc/wireguard/wgcf-profile.conf ]]; then
        conf=$(cat /etc/wireguard/wgcf-profile.conf)
    elif command -v warp >/dev/null 2>&1; then
        conf=$(warp -4 2>/dev/null || cat /root/wgcf.conf 2>/dev/null)
    fi
    echo -e "
    Your WARP IPv4 WireGuard Account
    ======================================
         Wireguard Configuration

    ${conf:-No WARP WireGuard configuration found. Install WARP first.}
    ======================================
    "
    rm -fr /root/wgcf.conf
    read -n 1 -s -r -p "Press any key to return..." || true
}

akun6() {
    clear
    local conf=""
    if [[ -f /etc/wireguard/wgcf.conf ]]; then
        conf=$(cat /etc/wireguard/wgcf.conf)
    elif [[ -f /etc/wireguard/wgcf-profile.conf ]]; then
        conf=$(cat /etc/wireguard/wgcf-profile.conf)
    elif command -v warp >/dev/null 2>&1; then
        conf=$(warp -6 2>/dev/null || cat /root/wgcf.conf 2>/dev/null)
    fi
    echo -e "
    Your WARP IPv6 WireGuard Account
    ======================================
         Wireguard Configuration

    ${conf:-No WARP WireGuard configuration found. Install WARP first.}
    ======================================
    "
    rm -fr /root/wgcf.conf
    read -n 1 -s -r -p "Press any key to return..." || true
}

token() {
    clear
    read -p "Input Your Token Teams WARP+: " token || return
    clear
    if command -v warp >/dev/null 2>&1; then
        warp -T "$token"
    elif [[ -x /usr/bin/warp.sh ]]; then
        echo "Teams token registration requires fscarmen warp client."
    else
        echo "WARP is not installed. Install WARP first."
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to return..." || true
}

add() {
    clear
    echo -e "
    Create Cloudflare WARP Account
    ==============================

    1. Create Account (IPv4)
    2. Create Account (IPv6)
    ==============================
    Press [Ctrl + C] to exit"
    read -p "Input option: " aws || exit 0
    case $aws in
    1) akun4 ;;
    2) akun6 ;;
    *) add ;;
    esac
}

menuwg() {
    clear
    echo -e "
        Cloudflare WARP Menu
    ==========================

    1. Install Cloudflare WARP
    2. WARP Service Status
    3. Restart WARP Service
    4. Enable WARP Service
    5. Disable WARP Service
    6. Enter WARP Teams Token
    ==========================
    
    7. Create WARP Account
    8. Back to Main Menu
    9. Exit
    ==========================
    Press [Ctrl + C] to exit"
    read -p "Input option: " opt || exit 0
    case $opt in
    1) install ;;
    2) status ;;
    3) restart ;;
    4) enable ;;
    5) disable ;;
    6) token ;;
    7) add ;;
    8) menu ;;
    9) exit ;;
    *) menuwg ;;
    esac
}
menuwg
}

    change_timezone() {

    clear
echo -e "\e[32m════════════════════════════════════════" | lolcat
echo -e "\033[0;36m ═══[ \033[0m\e[1mCHANGE TIMEZONE\033[0;34m ]═══"
echo -e "\e[32m════════════════════════════════════════" | lolcat
echo -e " 1)  Malaysia (GMT +8:00)"
echo -e " 2)  Indonesia (GMT +7:00)"
echo -e " 3)  Singapore (GMT +8:00)"
echo -e " 4)  Brunei (GMT +8:00)"
echo -e " 5)  Thailand (GMT +7:00)"
echo -e " 6)  Philippines (GMT +8:00)"
echo -e " 7)  India (GMT +5:30)"
echo -e " 8)  Japan (GMT +9:00)"
echo -e " 9)  View Current Time Zone"
echo -e ""
echo -e "\e[1;32m══════════════════════════════════════════\e[m" | lolcat
echo -e " x)   MAIN MENU"
echo -e "\e[1;32m══════════════════════════════════════════\e[m" | lolcat
echo -e ""
read -p " Select menu :  "  opt || exit 0
echo -e ""
case $opt in
		1)
		clear
		timedatectl set-timezone Asia/Kuala_Lumpur
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m            Time Zone Set Asia Malaysia  "
		echo -e "\e[0m                                                   "
	    echo -e "\e[1;32m══════════════════════════════════════════\e[m"
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		2)
		clear
		timedatectl set-timezone Asia/Jakarta
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m           Time Zone Set Asia Indonesia "
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		3)
		clear
		timedatectl set-timezone Asia/Singapore
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m           Time Zone Set Asia Singapore "
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		4)
		clear
		timedatectl set-timezone Asia/Brunei
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m            Time Zone Set Asia Brunei   "
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		5)
		clear
		timedatectl set-timezone Asia/Bangkok
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m            Time Zone Set Asia Thailand  "
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		6)
		clear
		timedatectl set-timezone Asia/Manila
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
		echo -e "\e[0;37m        Time Zone Set Asia Philippines"
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		7)
		clear
		timedatectl set-timezone Asia/Kolkata
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m            Time Zone Set Asia India"
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
        8)
		clear
		timedatectl set-timezone Asia/Tokyo
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo -e "\e[0m                                                   "
	    echo -e "\e[0m            Time Zone Set Asia Japan"
		echo -e "\e[0m                                                   "
		echo -e "\e[1;32m══════════════════════════════════════════\e[m"
		echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
		9)
		clear
        echo ""
		timedatectl
	    echo ""
        read -sp " Press ENTER to go back"
        echo ""
        change_timezone
		;;
        x)
		clear
		menu
		;;
		*)
		change_timezone
		;;
	esac
	
	}

detail() {
clear
echo -e "\n
===============================
Autoscript Management Panel VPN
===============================

XTLS:
- WEBSOCKET
- HTTP UPGRADE
- SPLIT HTTP
- gRPC

Feature:
- Multipath & Dynamic Path
- Custom Domain
- Routing XTLS ALL CORE
- Multiport 443 & 80 on server
- Auto Configure Server
- Auto Backup & Full Notif Telegram
===============================
\n"
read -n 1 -s -r -p "Press any key to return..." || true
echo ""
}


uninstall() {
clear

openeuler() {
clear
echo -e "${NC}${separator}
         OPENEULER LINUX
${separator}
${green}1${NC}. OpenEuler 20.03
${green}2${NC}. OpenEuler 22.03
${green}3${NC}. OpenEuler 24.03
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Option: " opn || exit 0
case $opn in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 20.03 && reboot  ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 22.03 && reboot  ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 24.03 && reboot  ;;
*) openeuler
esac
}

opensuse() {
clear
echo -e "${NC}${separator}
          OPENSUSE LINUX
${separator}
${green}1${NC}. OpenSuse 16.0
${green}2${NC}. OpenSuse Tumbleweed
${green}3${NC}. OpenSuse tumbleweed
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Option: " osu || exit 0
case $osu in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse 16.0 && reboot  ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse tumbleweed && reboot  ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse tumbleweed && reboot  ;;
*) opensuse ;;
esac
}

debian() {
clear
echo -e "${NC}${separator}
           DEBIAN LINUX
${separator}
${green}1${NC}. Debian 9
${green}2${NC}. Debian 10
${green}3${NC}. Debian 11
${green}4${NC}. Debian 12
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Option: " db || exit 0
case $db in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 9 && reboot  ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 10 && reboot  ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 11 && reboot  ;;
4) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 12 && reboot  ;;
*) debian ;;
esac
}

ubuntu() {
clear
echo -e "${NC}${separator}
           UBUNTU LINUX
${separator}
${green}1${NC}. Ubuntu 26.04
${green}2${NC}. Ubuntu 18.04
${green}3${NC}. Ubuntu 20.04
${green}4${NC}. Ubuntu 22.04
${green}5${NC}. Ubuntu 24.04
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Option: " wq || exit 0
case $wq in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 26.04 && reboot ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 18.04 && reboot ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 20.04 && reboot ;;
4) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 22.04 && reboot ;;
5) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 24.04 && reboot ;;
*) ubuntu ;;
esac
}

alpine() {
clear
echo -e "${NC}${separator}
           ALPINE LINUX
${separator}
${green}1${NC}. Alpine 3.21
${green}2${NC}. Alpine 3.22
${green}3${NC}. Alpine 3.23
${green}4${NC}. Alpine 3.24
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Option: " ap || exit 0
case $ap in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.21 && reboot ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.22 && reboot ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.23 && reboot ;;
4) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.24 && reboot ;;
*) clear ; alpine ;;
esac
}

rocky() {
echo -e "${NC}${separator}
            ROCKY LINUX
${separator}
${green}1${NC}. Rocky Linux 8
${green}2${NC}. Rocky Linux 9
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input Options: " opw || exit 0
case $opw in
1) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh rocky 8 && reboot ;;
2) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh rocky 9 && reboot ;;
*) rocky ;;
esac
}

information() {
uuid="123@@@"
clear
echo -e "
[ New Data Your VPS ]
=====================
Username: root
Password: $uuid
=====================
Please Save Your Data
"
read -p "Continue (y/n): " osw
if [[ $osw == "y" ]]; then
os
elif [[ $osw == "n" ]]; then
exit
fi
}

os() {
    clear
    echo -e "
< = [ Select New OS ] = >
=========================

01. Rocky
02. Alpine
03. Anolis
04. Debian
05. Ubuntu
06. RedHat
07. CentOS
08. AlmaLinux
09. OpenEuler
10. OpenSUSE
11. Arch Linux
12. NixOS Linux
13. Oracle Linux
14. Fedora Linux
15. Gentoo Linux
16. Open Cloud OS
17. Kali Linux / Kali Rolling

=========================
Press CTRL + C to Exit
"
    read -p "Input Options: " os || exit 0
    case $os in
        01|1) clear ; rocky ;;
        02|2) clear ; alpine ;;
        03|3) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh anolis 8 && reboot ;;
        04|4) clear ; debian ;;
        05|5) clear ; ubuntu ;;
        06|6) clear ; echo -e "Coming Soon" ;; #redhat;;
        07|7) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh centos 9 && reboot ;;
        08|8) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh almalinux 9 && reboot ;;
        09|9) clear ; openeuler ;;
        10) clear ; opensuse ;;
        11) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh arch && reboot  ;;
        12) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh nixos 26.05 && reboot ;;
        13) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh oracle 8 && reboot ;;
        14) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh fedora 43 && reboot ;;
        15) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh gentoo && reboot  ;;
        16) clear ; cd /root ;curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opencloudos 8 && reboot ;;
        17) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh kali rolling && reboot  ;;
        *) clear ; echo "Invalid option. Please select a valid number.";;
    esac
}

tampilan() {
clear
echo -e "
==========================
< = [ Reinstall OS ] = >
==========================

1. Reinstall OS
2. Back to Main Menu
==========================
[ Press Ctrl + C to Exit ]
==========================
  Autoscript FN AutoSC
"
read -p "Input option: " ws || exit 0
case $ws in
1) clear ; os ;; #information ;; #os ;;
2) menu ;;
*) tampilan ;;
esac
}

tampilan
}

systemd() {
clear
echo -e "${NC}${separator}
            SYSTEM MENU
${separator}
${green}1${NC}. Change Timezone
${green}2${NC}. Restart All Services
${green}3${NC}. Cloudflare WARP (KVM Only)
${green}4${NC}. Reinstall OS / Rebuild Server
${green}5${NC}. View Service & Port Details
${green}6${NC}. System Resource Monitor (htop)
${green}7${NC}. Cloudflare Argo Tunnel Menu
${green}8${NC}. Change SSH Banner
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
read -p "Input option: " asu || exit 0
case $asu in
1) clear ; change_timezone ;;
2) clear ; resall ;;
3) clear ; menu-warp ;;
4) clear ; uninstall ;;
5) clear ; detail ;;
6) clear ; htop ;;
7) clear ; menu-argo ;;
8) clear ; bnnr ;;
*) systemd ;;
esac
}
systemd
