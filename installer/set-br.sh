#!/bin/bash
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/rclone-install.sh | bash
printf "q\n" | rclone config
#wget -O /root/.config/rclone/rclone.conf "${hosting}/config/rclone.conf"
wget -O /root/.config/rclone/rclone.conf "https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/rclone.conf"
git clone  https://github.com/rohjagad/wondershaper.git
cd wondershaper
make install
rm -rf wondershaper
echo > /home/limit
echo "msmtp-mta msmtp-mta/apparmor boolean false" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install msmtp-mta ca-certificates bsd-mailx -y
cat<<EOF>>/etc/msmtprc
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default
host smtp.gmail.com
port 587
auth on
user revolution.become.true@gmail.com
from revolution.become.true@gmail.com
password rmjydsqnwhehcanj  
logfile ~/.msmtp.log
EOF
sudo iptables -A INPUT -p tcp --dport 587 -j ACCEPT
sudo ufw allow 587/tcp
chown -R www-data:www-data /etc/msmtprc
cd /usr/bin
rm -f /root/set-br.sh