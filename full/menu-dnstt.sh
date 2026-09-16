#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/rohtunnel-autosc-auth/main/izin.txt"
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
red='\e[31m'
green='\e[32m'
NC='\033[0;37m'
white='\033[0;97m'
    mna89() {
        clear
            status="$(systemctl show dnstt.service --no-page)"
            status_text=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)
        clear
        echo -e "
        =============================
        <= Slow DNS / DNSTT Tunnel =>
        ============================="
        
        if [ "${status_text}" == "active" ]; then
            echo -e "        ${white}慢速 DNS 隧道${NC}: "${green}"running"$NC" ✓"
        else
            echo -e "        ${white}慢速 DNS 隧道${NC}: "$red"not running (Error)"$NC" "
        fi

        echo -e "
        1. Change Nameserver
        2. Renew Public Key & Server Key
        3. Restart DNSTT Tunnel on server
	4. Setup DNSTT Type
        0. Exit to menu
        =============================
        Press CTRL + C to Exit"
        
        read -p "Input Options: " dn1
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
                Description=SlowDNS FN Project Autoscript Service
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
                Success Change Nameserver DNSTT
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
                Success Renew Public Key & Server Key Slowdns
                ============================================="
                ;;
            3)
                clear
                systemctl daemon-reload
                systemctl restart dnstt.service
                clear
                echo -e "
                Success Restart SlowDNS
                ========================"
                ;;
	    4)
 	        clear
 	        typer
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
