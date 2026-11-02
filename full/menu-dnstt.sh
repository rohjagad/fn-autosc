#!/bin/bash
# Found 525: license is enforced only for create/extend/install.


[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


clear
echo ""
echo ""
red='\033[0;31m'
green='\033[0;32m'
blue='\033[1;34m'
purple='\033[1;35m'
orange='\033[38;5;208m'
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
        echo ""
        echo ""
        echo -e "${NC}${separator}
            SLOWDNS MENU
${separator}
Status       : $stat_msg
${blue_sep}
${green}1${NC}. Change Nameserver
${green}2${NC}. Renew Server Keys
${green}3${NC}. Restart SlowDNS Service
${green}4${NC}. View SlowDNS Information & Keys
${green}0${NC}. Back to Main Menu
${separator}

${orange}Press [Ctrl + C] to exit${NC}"
        
        read -p "Input option: " dn1 || exit 0
        case $dn1 in
            1)
                clear
                echo ""
                echo ""
                nsd=$(cat /etc/slowdns/nsdomain 2>/dev/null || echo "No nameserver found.")
                clear
                echo ""
                echo ""
                echo -e "${separator}
         Change Nameserver
${separator}
Nameserver   : $nsd
${separator}"
                echo ""
                read -p "Input Nameserver: " nsdomen || return
                if [ -z "$nsdomen" ]; then
                    echo "Nameserver cannot be empty."
                    sleep 2
                    mna89
                    return
                fi
                if ! [[ "$nsdomen" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
                    echo "Nameserver must be a valid DNS hostname."
                    sleep 2
                    mna89
                    return
                fi
                clear
                echo ""
                echo ""
                echo "${nsdomen}" > /etc/slowdns/nsdomain
                systemctl stop dnstt.service
                systemctl disable dnstt.service
                clear
                echo ""
                echo ""
                cat > /etc/systemd/system/dnstt.service << SVCEOF
[Unit]
Description=SlowDNS FN AutoSC Autoscript Service
Documentation=https://t.me/rohcuan
After=network.target nss-lookup.target
StartLimitIntervalSec=120
StartLimitBurst=30

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key $nsdomen 127.0.0.1:22
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
SVCEOF
                systemctl daemon-reload
                systemctl enable dnstt
                systemctl start dnstt
                clear
                echo ""
                echo ""
                echo -e "${separator}
   Nameserver Updated Successfully
${separator}
 Nameserver   : $nsdomen
${separator}"
                read -n 1 -s -r -p "Press any key to return..." || true
                mna89
                ;;
            2)
                clear
                echo ""
                echo ""
                systemctl stop dnstt.service
                systemctl disable dnstt.service
                clear
                echo ""
                echo ""
                chmod +x /etc/slowdns/dns-server
                /etc/slowdns/dns-server -gen-key -privkey-file /etc/slowdns/server.key -pubkey-file /etc/slowdns/server.pub
                chmod 600 /etc/slowdns/server.key 2>/dev/null || true
                systemctl daemon-reload
                systemctl enable dnstt.service
                systemctl start dnstt.service
                clear
                echo ""
                echo ""
                echo -e "${separator}
  Server Keys Renewed Successfully
${separator}"
                read -n 1 -s -r -p "Press any key to return..." || true
                mna89
                ;;
            3)
                clear
                echo ""
                echo ""
                systemctl daemon-reload
                systemctl restart dnstt.service
                clear
                echo ""
                echo ""
                echo -e "${separator}
  SlowDNS Restarted Successfully
${separator}"
                read -n 1 -s -r -p "Press any key to return..." || true
                mna89
                ;;
            4)
                clear
                echo ""
                echo ""
                nsd=$(cat /etc/slowdns/nsdomain 2>/dev/null || echo "N/A")
                pubkey=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "N/A")
                echo -e "${NC}${separator}
        SLOWDNS INFORMATION
${separator}
Nameserver   : ${green}$nsd${NC}
Public Key   : ${green}$pubkey${NC}
Port         : 53
Service      : $stat_msg
${separator}"
                read -n 1 -s -r -p "Press any key to return..." || true
                mna89
                ;;
            0|00)
                clear
                echo ""
                echo ""
                menu
                ;;
            *)
                clear
                echo ""
                echo ""
                mna89
                ;;
        esac
    }
    mna89
