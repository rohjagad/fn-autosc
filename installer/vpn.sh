#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -s ifconfig.me) # Mendapatkan IP lokal

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
        echo "Permission expired."
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
red='\e[1;31m'
green='\e[0;32m'
blue='\e[0;34m'
cyan='\e[0;36m'
cyanb='\e[46m'
white='\e[037;1m'
grey='\e[1;36m'
NC='\e[0m'
# ==================================================
# Lokasi Hosting Penyimpan autoscript
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"

# var installation
export DEBIAN_FRONTEND=noninteractive
OS=`uname -m`;
MYIP=$(wget -qO- icanhazip.com);
MYIP2="s/xxxxxxxxx/$MYIP/g";
ANU=$(ip -o -4 route show to default | awk '{print $5}');

# Install OpenVPN dan Easy-RSA
apt install openvpn -y
apt install openvpn easy-rsa -y
apt install unzip -y
apt install openssl iptables iptables-persistent -y
mkdir -p /etc/openvpn/server/easy-rsa/
cd /etc/openvpn/
wget ${hosting}/other/vpn.zip
unzip -o vpn.zip
rm -f vpn.zip
chown -R root:root /etc/openvpn/server/easy-rsa/

cd
mkdir -p /usr/lib/openvpn/
cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so

# nano /etc/default/openvpn
sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn

# restart openvpn dan cek status openvpn
systemctl enable --now openvpn-server@server-tcp-1194
systemctl enable --now openvpn-server@server-udp-2200
/etc/init.d/openvpn restart
/etc/init.d/openvpn status

# aktifkan ip4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# Buat config client TCP 1194
cat > /etc/openvpn/client-tcp-1194.ovpn <<-END
client
dev tun
proto tcp
setenv FRIENDLY_NAME "Beginner TCP"
remote xxxxxxxxx 1194
http-proxy xxxxxxxxx 3128
resolv-retry infinite
route-method exe
auth-user-pass
auth-nocache
nobind
persist-key
persist-tun
comp-lzo
verb 3
END

sed -i $MYIP2 /etc/openvpn/client-tcp-1194.ovpn;

# Buat config client UDP 2200
cat > /etc/openvpn/client-udp-2200.ovpn <<-END
client
dev tun
proto udp
setenv FRIENDLY_NAME "Beginner UDP"
remote xxxxxxxxx 2200
resolv-retry infinite
route-method exe
auth-user-pass
auth-nocache
nobind
persist-key
persist-tun
comp-lzo
verb 3
END

sed -i $MYIP2 /etc/openvpn/client-udp-2200.ovpn;

cd
# pada tulisan xxx ganti dengan alamat ip address VPS anda
/etc/init.d/openvpn restart

# masukkan certificatenya ke dalam config client TCP 1194
echo '<ca>' >> /etc/openvpn/client-tcp-1194.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/client-tcp-1194.ovpn
echo '</ca>' >> /etc/openvpn/client-tcp-1194.ovpn

# Copy config OpenVPN client ke home directory root agar mudah didownload ( TCP 1194 )
cp /etc/openvpn/client-tcp-1194.ovpn /var/www/html/client-tcp-1194.ovpn
# Alias dengan nama yang dipakai menu (Config OVPN: /web/tcp.ovpn).
# location /web/ di nginx memetakan ke /var/www/html/ langsung.
cp /etc/openvpn/client-tcp-1194.ovpn /var/www/html/tcp.ovpn

# masukkan certificatenya ke dalam config client UDP 2200
echo '<ca>' >> /etc/openvpn/client-udp-2200.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/client-udp-2200.ovpn
echo '</ca>' >> /etc/openvpn/client-udp-2200.ovpn

# Copy config OpenVPN client ke home directory root agar mudah didownload ( UDP 2200 )
cp /etc/openvpn/client-udp-2200.ovpn /var/www/html/client-udp-2200.ovpn
# Alias UDP dengan nama yang dipakai menu.
cp /etc/openvpn/client-udp-2200.ovpn /var/www/html/udp.ovpn

#firewall untuk memperbolehkan akses UDP dan akses jalur TCP

iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $ANU -j MASQUERADE
iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $ANU -j MASQUERADE
iptables-save > /etc/iptables.up.rules
chmod +x /etc/iptables.up.rules

iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# Restart service openvpn
systemctl daemon-reload
systemctl enable openvpn
systemctl start openvpn
/etc/init.d/openvpn restart

# Membuat File Zip OVPN
cd /var/www/html
zip openvpn.zip *.ovpn
cd

# Menginstall OHP
cd /usr/sbin
wget --no-check-certificate ${hosting}/other/fnohp >> /dev/null 2>&1
chmod +x fnohp
cd /etc
wget --no-check-certificate ${hosting}/other/fn.ohp >> /dev/null 2>&1
chmod +x fn.ohp
cd

# systemd ohp
cat > /etc/systemd/system/fn-ohp.service <<-END
[Unit]
Description=FNOHP Service on Port 9088
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/fnohp -port 9088 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:1194
Restart=always
User=root

[Install]
WantedBy=multi-user.target
END

# Menginstall Squid Proxy
apt-get -y install squid
rm -f /etc/squid/squid.conf
wget -O /etc/squid/squid.conf "${hosting}/config/squid.conf" >> /dev/null 2>&1
MYIP1=$(wget -qO- ipv4.icanhazip.com);
MYIP3="s/rerechan/$MYIP1/g";
sed -i $MYIP3 /etc/squid/squid.conf
service squid restart

# Enable Service
systemctl daemon-reload
systemctl enable fn-ohp
systemctl start fn-ohp


# Menginstall Websocket OpenVPN
cd /usr/local/bin
wget --no-check-certificate ${hosting}/other/dinda >> /dev/null 2>&1

# Menginstall Package
apt install python3 -y

# Membuat Service
cat> /etc/systemd/system/opn.service << END
[Unit]
Description=Python Proxy Mod By geovpn
Documentation=https://t.me/geovpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O /usr/local/bin/dinda
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

# Mengaktifkan Service
systemctl daemon-reload
systemctl enable opn
systemctl start opn

# Delete script
history -c
rm -f /root/*.sh
rm -f /root/install
rm -f /root/*install*
