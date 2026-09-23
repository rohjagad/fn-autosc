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

    mna89() {
        status="$(systemctl show dnstt.service --no-page)"
        status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
        if [ "${status_text}" == "active" ]; then
            stat_msg="${green}ON${NC}"
        else
            stat_msg="${red}OFF${NC}"
        fi
        clear
        echo -e "${NC}${separator}
            SLOWDNS MENU
${separator}
Status       : $stat_msg
${blue_sep}
${green}1${NC}. Change Nameserver
${green}2${NC}. Renew Server Keys
${green}3${NC}. Restart SlowDNS Service
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
        
        read -p "Input option: " dn1
        case $dn1 in
            1)
                clear
                nsd=$(cat /etc/slowdns/nsdomain 2>/dev/null || echo "No nameserver found.")
                clear
                echo -e "
                =================
                Change Nameserver
                =================
                Nameserver: $nsd
                "
                read -p "Input Nameserver: " nsdomen
                clear
                echo "${nsdomen}" > /etc/slowdns/nsdomain
                systemctl stop dnstt.service
                systemctl disable dnstt.service
                clear
                
                echo -e "[Unit]
                Description=SlowDNS FN AutoSC Autoscript Service
                Documentation=https://t.me/fn_project
                After=network.target nss-lookup.target

                [Service]
                Type=simple
                User=root
                CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
                AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
                NoNewPrivileges=true
                ExecStart=/etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key $nsdomen 127.0.0.1:22
                Restart=on-failure

                [Install]
                WantedBy=multi-user.target" > /etc/systemd/system/dnstt.service
                systemctl daemon-reload
                systemctl enable dnstt
                systemctl start dnstt
                clear
                echo -e "
                Nameserver Updated Successfully
                ===============================
                New Nameserver: $nsdomen
                ==============================="
                ;;
            2)
                clear
                systemctl stop dnstt.service
                systemctl disable dnstt.service
                clear
                chmod +x /etc/slowdns/dns-server
                /etc/slowdns/dns-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub
                systemctl daemon-reload
                systemctl enable dnstt.service
                systemctl start dnstt.service
                clear
                echo -e "
                Server Keys Renewed Successfully
                ================================"
                ;;
            3)
                clear
                systemctl daemon-reload
                systemctl restart dnstt.service
                clear
                echo -e "
                SlowDNS Restarted Successfully
                =============================="
                ;;
            0)
                menu
                ;;
            *)
                clear
                mna89
                ;;
        esac
    }
    mna89
