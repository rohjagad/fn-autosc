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
NC='\e[0m'
echo "Please Wait ...."
REQUIRED_PACKAGES=("curl" "wget" "dnsutils" "git" "screen" "whois" "pwgen" "python" "jq" "fail2ban" "sudo" "gnutls-bin" "mlocate" "dh-make" "libaudit-dev" "build-essential" "dos2unix" "debconf-utils")

for package in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg-query -W --showformat='${Status}\n' $package | grep -q "install ok installed"; then
    apt-get -qq install $package -y &>/dev/null
  fi
done
clear
rm -fr /usr/bin/go ; wget https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/go1.22.0.linux-amd64.tar.gz ; sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz ; rm -fr /root/go1.22.0.linux-amd64.tar.gz ; echo "export PATH="/usr/local/go/bin:$PATH:/rere"" >> /root/.bashrc ; cd ; source .bashrc ; go version

install_slowdns() {
  export PATH="/usr/local/go/bin:$PATH"
  cd /root
  rm -rf /etc/slowdns /root/dnstt
  git clone --depth 1 https://github.com/rohjagad/dnstt.git /root/dnstt
  cd /root/dnstt/dnstt-server
  rm -fr go.sum
  go mod tidy
  go build
  mkdir -p /etc/slowdns/
  mv dnstt-server /etc/slowdns/dns-server
  chmod +x /etc/slowdns/dns-server
  /etc/slowdns/dns-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub
  rm -rf /root/dnstt

  clear
  echo -e "
========================
SlowDNS / DNSTT Settings
========================"
  read -rp "Your Nameserver: " -e Nameserver
  echo -e "$Nameserver" > /etc/slowdns/nsdomain

  rm -f /etc/systemd/system/dnstt.service
  systemctl stop dnstt 2>/dev/null || true
  pkill dns-server 2>/dev/null || true

  cat >/etc/systemd/system/dnstt.service <<END
[Unit]
Description=SlowDNS FN AutoSC Autoscript Service
Documentation=https://t.me/fn_project
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

  systemctl daemon-reload
  systemctl enable dnstt
  systemctl start dnstt

  sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
  systemctl restart ssh
}

install_firewall() {
  local interface=$(ip route get 8.8.8.8 | awk '/dev/ {print $5}')
  iptables -I INPUT -p udp --dport 5300 -j ACCEPT &>/dev/null
  iptables -t nat -I PREROUTING -i $interface -p udp --dport 53 -j REDIRECT --to-ports 5300
  local interface2=$(ip route get 1.1.1.1 | awk '/dev/ {print $5}')
  iptables -I INPUT -p udp --dport 530 -j ACCEPT &>/dev/null
  iptables -t nat -I PREROUTING -i $interface2 -p udp --dport 53 -j REDIRECT --to-ports 530
  iptables-save >/etc/iptables.up.rules
  iptables-restore < /etc/iptables.up.rules
  netfilter-persistent save
  netfilter-persistent reload
}

install_slowdns
install_firewall

rm -rf /root/slowdns.sh
#rm -rf /root/*.sh
clear
echo -e ""
echo -e "Installing Patch SlowDNS Autoscript done..."
echo "done .."
#reboot
