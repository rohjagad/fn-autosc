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

clear

bnnr() {
read -p "Input Your Banner" bns
echo -e "$bns" > /etc/issue.net
systemctl daemon-reload
systemctl restart dropbear
systemctl restart ws
clear
echo -e "
=====================
Success Change Banner
=====================
"
}

resall() {
clear
echo -e "Start Restart All Service"
systemctl daemon-reload
systemctl restart ssh
systemctl restart ws
systemctl restart cron
systemctl restart v2ray
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
}

menu-warp() {
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Red_font_prefix}[information]${Font_color_suffix}"

clear

install() {
clear
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

if [[ -e /etc/wireguard/params ]]; then
        echo -e "${Info} WireGuard sudah diinstal."
        exit 1
fi

# Install WireGuard tools and module
        if [[ $OS == 'ubuntu' ]]; then
        apt install -y wireguard
elif [[ $OS == 'debian' ]]; then
        echo "deb http://deb.debian.org/debian/ unstable main" >/etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' >/etc/apt/preferences.d/limit-unstable
        apt update
        apt install -y wireguard-tools iptables iptables-persistent
        apt install -y linux-headers-$(uname -r)
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
chmod /usr/bin/warp.sh
chmod +x /usr/bin/*
clear
}

status() {
    clear
    warp.sh status
    curl -s https://www.cloudflare.com/cdn-cgi/trace
}

enable() {
    warp-cli connect
    clear
    echo -e "Done Enable Warp"
}

disable() {
    warp-cli disconnect
    clear
    echo -e "success disable warp"
}

restart() {
    warp.sh restart
    systemctl daemon-reload
    systemctl restart wg-quick@wgcf
    clear
    echo -e "Done Restart Service Warp Wireguard"
}

akun4() {
    warp -4 > /root/wgcf.conf
    clear
    echo -e "
    <= Your WARP IPv4 Wireguard Account =>
    ======================================
         Wireguard Configuration

    $(cat /root/wgcf.conf)
    ======================================
    "
    rm -fr /root/wgcf.conf
}

akun6() {
        warp -6 > /root/wgcf.conf
    clear
    echo -e "
    <= Your WARP IPv6 Wireguard Account =>
    ======================================
         Wireguard Configuration

    $(cat /root/wgcf.conf)
    ======================================
    "
    rm -fr /root/wgcf.conf
}

token() {
    clear
    read -p "Input Your Token Teams WARP+: " token
    clear
    warp -T $token
}

add() {
    clear
    echo -e "
    Create Account Warp Wireguard
    =============================

    1. Create Account with IPv4
    2. Create Account with IPv6
    =============================
    Press CTRL + C To exit menu"
    read -p "Input Option: " aws
    case $aws in
    1) akun4 ;;
    2) akun6 ;;
    *) add ;;
    esac
}

menuwg() {
    clear
    echo -e "
      Menu Warp Wireguard FN
    ==========================

    1. Install Warp Wireguard
    2. Status Warp Wireguard
    3. Restart Warp Wireguard
    4. Enable Warp Wireguard
    5. Disable Warp Wireguard
    6. Input Token Warp Teams
    ==========================
    
    7. Create Account Wireguard
    8. Enter to default menu
    9. Exit this menu
    ==========================
    Press CTRL + C To Exit Menu"
    read -p "Input Option: " opt
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
echo -e " x)   MENU UTAMA"
echo -e "\e[1;32m══════════════════════════════════════════\e[m" | lolcat
echo -e ""
read -p " Select menu :  "  opt
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

SSH WEBSOCKET: 80, 443, 2080
SSH DROPBEAR : 109, 111
SSH OPENSSH  : 22
SSH SLOWDNS  : 53, 5300

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
}


uninstall() {
clear

openeuler() {
clear
echo -e "
======================
<= OpenEuler Linux =>
======================

1. OpenEuler 20.03
2. OpenEuler 22.03
3. OpenEuler 24.03
======================
"
read -p "Input Option: " opn
case $opn in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 20.03 && reboot  ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 22.03 && reboot  ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh openeuler 24.04 && reboot  ;;
*) openeuler
esac
}

opensuse() {
clear
echo -e "
====================
<= OpenSuse Linux =>
====================

1. OpenSuse 15.5
2. OpenSuse 16.6
3. OpenSuse tumbleweed
====================
"
read -p "Input Option: " osu
case $osu in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse 15.5 && reboot  ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse 15.6 && reboot  ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opensuse tumbleweed && reboot  ;;
*) opensuse ;;
esac
}

debian() {
clear
echo -e "
==================
<= Debian Linux =>
==================

1. Debian 9
2. Debian 10
3. Debian 11
4. Debian 12
==================
"
read -p "Input Option: " db
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
echo -e "
==================
<= Ubuntu Linux =>
==================

1. Ubuntu 16.04
2. Ubuntu 18.04
3. Ubuntu 20.04
4. Ubuntu 22.04
5. Ubuntu 24.04
==================
"
read -p "Input Option: " wq
case $wq in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 16.04 && reboot ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 18.04 && reboot ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 20.04 && reboot ;;
4) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 22.04 && reboot ;;
5) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh ubuntu 24.04 && reboot ;;
*) ubuntu ;;
esac
}

alpine() {
clear
echo -e "
==================
<= Alpine Linux =>
==================

1. Alpine 3.17
2. Alpine 3.18
3. Alpine 3.19
4. Alpine 3.20
==================
"
read -p "Input Option: " ap
case $ap in
1) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.17 && reboot ;;
2) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.18 && reboot ;;
3) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.19 && reboot ;;
4) cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alpine 3.20 && reboot ;;
*) clear ; alpine ;;
esac
}

rocky() {
echo -e "
=================
<= Rocky Linux =>
=================

1. Rocky Linux 8
2. Rocky Linux 9
=================
"
read -p "Input Options: " opw
case $opw in
1) clear : cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh rocky 8 && reboot ;;
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
elif [[ $ip_version == "n" ]]; then
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
    read -p "Input Options: " os
    case $os in
        01|1) clear ; rocky ;;
        02|2) clear ; alpine ;;
        03|3) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh anolis 8 && reboot ;;
        04|4) clear ; debian ;;
        05|5) clear ; ubuntu ;;
        06|6) clear ; echo -e "Coming Soon" ;; #redhat;;
        07|7) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh centos 9 && reboot ;;
        08|8) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh alma 9 && reboot ;;
        09|9) clear ; openeuler ;;
        10) clear ; opensuse ;;
        11) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh arch && reboot  ;;
        12) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh nixos 24.05 && reboot ;;
        13) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh oracle 8 && reboot ;;
        14) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh fedora 40 && reboot ;;
        15) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh gento && reboot  ;;
        16) clear ; cd /root ;curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh opencloudos 8 && reboot ;;
        17) clear ; cd /root ; curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh kali && reboot  ;;
        *) clear ; echo "Invalid option. Please select a valid number.";;
    esac
}

tampilan() {
clear
echo -e "
==========================
< = [ Menu Uninstall ] = >
==========================

1. Uninstall Script
2. Back To Default Menu
==========================
[ Press CTRL + C To Exit ]
==========================
  Autoscript RohFN AutoSC
"
read -p "Input Option: " ws
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
echo -e "\n
===========================================
       MENU SYSTEM / SERVICE SERVER
===========================================

1. Change Timezone
2. Restart All Service
3. Menu Warp Cloudflare [ Only VPS KVM ]
4. Uninstall / Rebuild Server
5. Cek Detail Port & Service
6. Cek Status Uptime, CPU, Ram & SSD USAGE
7. Setup Cloudflare Argo Tunnel Routing on your Server
8. Change Banner SSH
===========================================\n"
read -p "Input Option: " asu
case $asu in
1) change_timezone ;;
2) resall ;;
3) menu-warp ;;
4) uninstall ;;
5) detail ;;
6) htop ;;
7) clear ; menu-argo ;;
8) clear ; bnnr ;;
*) systemd ;;
esac
}
systemd
