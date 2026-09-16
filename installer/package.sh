#!/bin/bash

clear

# Install Package
apt update
apt install -y curl jq wget socat certbot zip unzip dnsutils git screen whois pwgen python fail2ban gnutls-bin mlocate dh-make build-essential dos2unix debconf-utils iptables htop
apt install at -y
apt install bc -y

# Menginstal Lolcat
apt install lolcat -y
apt install ruby -y
gem install lolcat

# Membuat Directory Database
mkdir -p /etc/funny
mkdir -p /etc/xray/json
mkdir -p /var/log/xray
mkdir -p /var/log/create/ssh
mkdir -p /var/log/create/xray/ws
mkdir -p /var/log/create/xray/split
mkdir -p /var/log/create/xray/http
mkdir -p /var/log/create/xray/grpc
mkdir -p /etc/slowdns
mkdir -p /etc/xray/limit/ip/xray/ws
mkdir -p /etc/xray/limit/ip/xray/http
mkdir -p /etc/xray/limit/ip/xray/split
mkdir -p /etc/xray/limit/ip/xray/grpc
mkdir -p /etc/xray/quota/ws
mkdir -p /etc/xray/quota/http
mkdir -p /etc/xray/quota/split
mkdir -p /etc/xray/quota/grpc
mkdir -p /etc/xray/limit/ip/ssh
mkdir -p /root/.rules

# Membuat File Log Database
touch /var/log/xray/ws.log
touch /var/log/xray/split.log
touch /var/log/xray/upgrade.log
touch /var/log/xray/http.log
touch /var/log/xray/grpc.log
touch /etc/xray/.quota.logs
touch /etc/funny/.l2tp
touch /etc/funny/.pptp
touch /etc/funny/.noob

# Installasi Ulang untuk menghindari package tidak terinstall
clear
red='\e[1;31m'
green='\e[1;32m'
yell='\e[1;33m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

echo "Tools install...!"
echo "Progress..."
sleep 2

apt update -y
apt dist-upgrade -y
apt-get remove --purge ufw firewalld -y 
apt-get remove --purge exim4 -y 
apt install htop -y


apt install -y screen curl jq bzip2 gzip coreutils rsyslog iftop \
 htop zip unzip net-tools sed gnupg gnupg1 \
 bc  apt-transport-https build-essential dirmngr libxml-parser-perl neofetch screenfetch git lsof \
 openssl openvpn easy-rsa fail2ban tmux \
 stunnel4 vnstat squid3 \
 dropbear  libsqlite3-dev \
 socat cron bash-completion ntpdate xz-utils  apt-transport-https \
 gnupg2 dnsutils lsb-release chrony

curl -sSL https://deb.nodesource.com/setup_16.x | bash - 
 apt-get install nodejs -y

/etc/init.d/vnstat restart
wget -q https://humdi.net/vnstat/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
cd
vnstat -u -i $NET
sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
rm -f /root/vnstat-2.6.tar.gz >/dev/null 2>&1
rm -rf /root/vnstat-2.6 >/dev/null 2>&1

apt install -y libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev flex bison make libnss3-tools libevent-dev xl2tpd pptpd

yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "Dependencies successfully installed..."
sleep 3
clear


