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
        echo "Your IP doesn’t have on database"
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
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"; fi
    }

    output
clear
echo ""
echo ""
echo ""
blue='\033[1;34m'
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

trojanjir() {
echo -e "
${separator}
[ Routing Seting ]
${separator}
Only XRAY Trojan WebSocket TLS Routing
${separator}"
read -p "Input Name: " names || return
read -p "Input Domain: " domain || return
read -p "Input Port: " port || return
read -p "Input Password: " password || return
read -p "Input Path: " path || return
if [[ -z "$names" || -z "$domain" || -z "$port" || -z "$password" || -z "$path" ]]; then
    echo "All fields are required."
    sleep 2
    return
fi
clear
echo ""
echo ""
echo ""
DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/xhttp.json"

# Mengecek apakah file domain ada, jika tidak, menggunakan default
if [ -f "$DOMAIN_FILE" ]; then
    rout=$(cat "$DOMAIN_FILE")
else
    rout='
    "ipinfo.io",
    "www.rerechan02.com"
    '
fi

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/xhttp.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)
[[ -z "$line" ]] && { echo "outbounds section not found in config"; return 2>/dev/null || exit 1; }

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/xhttp.json

# Membuat konfigurasi baru untuk "outbounds" dan "routing"
TEXT="
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    },
    {
      \"protocol\": \"trojan\",
      \"settings\": {
        \"servers\": [
          {
            \"address\": \"$domain\",
            \"port\": $port,
            \"password\": \"$password\"
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {
          \"path\": \"$path\"
        },
        \"security\": \"tls\"
      },
      \"tag\": \"$names\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
          \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      },
      {
        \"type\": \"field\",
        \"domain\": [
          $rout
        ],
        \"outboundTag\": \"$names\"
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true,
        \"statsUserOnline\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\": true,
      \"statsOutboundDownlink\": true
    }
  }
}"

# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Reload dan restart Xray service
systemctl daemon-reload
systemctl restart xray@xhttp

clear
echo ""
echo ""
echo ""
echo -e "Routing Success With Trojan WebSocket TLS"
}

vlessjir() {
echo -e "
${separator}
[ Routing Seting ]
${separator}
Only XRAY Vless None TLS
${separator}"
read -p "Input Name: " names || return
read -p "Input Domain: " domain || return
read -p "Input Port: " port || return
read -p "Input UUID: " uid || return
read -p "Input Path: " path || return
if [[ -z "$names" || -z "$domain" || -z "$port" || -z "$uid" || -z "$path" ]]; then
    echo "All fields are required."
    sleep 2
    return
fi
clear
echo ""
echo ""
echo ""
DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/xhttp.json"

# Mengecek apakah file domain ada, jika tidak, menggunakan default
if [ -f "$DOMAIN_FILE" ]; then
    rout=$(cat "$DOMAIN_FILE")
else
    rout='
    "ipinfo.io",
    "www.rerechan02.com"
    '
fi

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/xhttp.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)
[[ -z "$line" ]] && { echo "outbounds section not found in config"; return 2>/dev/null || exit 1; }

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/xhttp.json

# Membuat konfigurasi baru untuk "outbounds" dan "routing"
TEXT="
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    },
    {
      \"protocol\": \"vless\",
      \"settings\": {
        \"vnext\": [
          {
            \"address\": \"$domain\",
            \"port\": $port,
            \"users\": [
              {
                \"id\": \"$uid\"
              }
            ]
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {
          \"path\": \"$path\"
        }
      },
      \"tag\": \"$names\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
          \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      },
      {
        \"type\": \"field\",
        \"domain\": [
          $rout
        ],
        \"outboundTag\": \"$names\"
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true,
        \"statsUserOnline\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\": true,
      \"statsOutboundDownlink\": true
    }
  }
}"

# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Reload dan restart Xray service
systemctl daemon-reload
systemctl restart xray@xhttp

clear
echo ""
echo ""
echo ""
echo -e "Routing Success With All Protocol XRAY WebSocket using Xray Vless WS NoneTLS"
}

vmessjir() {
echo -e "
${separator}
[ Routing Setting ]
${separator}
Only XRAY VMESS None TLS
${separator}"

read -p "Input Name: " names || return
read -p "Input Domain: " domain || return
read -p "Input Port: " port || return
read -p "Input UUID: " uid || return
read -p "Input Path: " path || return
if [[ -z "$names" || -z "$domain" || -z "$port" || -z "$uid" || -z "$path" ]]; then
    echo "All fields are required."
    sleep 2
    return
fi
clear
echo ""
echo ""
echo ""
DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/xhttp.json"

# Mengecek apakah file domain ada, jika tidak, menggunakan default
if [ -f "$DOMAIN_FILE" ]; then
    rout=$(cat "$DOMAIN_FILE")
else
    rout='
    "ipinfo.io",
    "www.rerechan02.com"
    '
fi

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/xhttp.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)
[[ -z "$line" ]] && { echo "outbounds section not found in config"; return 2>/dev/null || exit 1; }

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/xhttp.json

# Membuat konfigurasi baru untuk "outbounds" dan "routing"
TEXT="
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    },
    {
      \"protocol\": \"vmess\",
      \"settings\": {
        \"vnext\": [
          {
            \"address\": \"$domain\",
            \"port\": $port,
            \"users\": [
              {
                \"id\": \"$uid\",
                \"alterId\": 0
              }
            ]
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {
          \"path\": \"$path\"
        }
      },
      \"tag\": \"$names\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
          \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      },
      {
        \"type\": \"field\",
        \"domain\": [
          $rout
        ],
        \"outboundTag\": \"$names\"
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true,
        \"statsUserOnline\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\": true,
      \"statsOutboundDownlink\": true
    }
  }
}"

# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Reload dan restart Xray service
systemctl daemon-reload
systemctl restart xray@xhttp

clear
echo ""
echo ""
echo ""
echo -e "Routing Success With All Protocol XRAY VMESS WebSocket Non-TLS"
}



resd() {
# Mengambil Lokasi Xray Config
XRAY_CONFIG="/etc/xray/json/xhttp.json"

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/xhttp.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)
[[ -z "$line" ]] && { echo "outbounds section not found in config"; return 2>/dev/null || exit 1; }

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/xhttp.json
TEXT="
    \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {}
    },
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"ip\": [
         \"0.0.0.0/8\",
          \"10.0.0.0/8\",
          \"100.64.0.0/10\",
          \"169.254.0.0/16\",
          \"172.16.0.0/12\",
          \"192.0.0.0/24\",
          \"192.0.2.0/24\",
          \"192.168.0.0/16\",
          \"198.18.0.0/15\",
          \"198.51.100.0/24\",
          \"203.0.113.0/24\",
          \"::1/128\",
          \"fc00::/7\",
          \"fe80::/10\"
        ],
        \"outboundTag\": \"blocked\"
      },
      {
        \"inboundTag\": [
          \"api\"
        ],
        \"outboundTag\": \"api\",
        \"type\": \"field\"
      },
      {
        \"type\": \"field\",
        \"outboundTag\": \"blocked\",
        \"protocol\": [
          \"bittorrent\"
        ]
      }
    ]
  },
  \"stats\": {},
  \"api\": {
    \"services\": [
      \"StatsService\"
    ],
    \"tag\": \"api\"
  },
  \"policy\": {
    \"levels\": {
      \"0\": {
        \"statsUserDownlink\": true,
        \"statsUserUplink\": true,
        \"statsUserOnline\": true
      }
    },
    \"system\": {
      \"statsInboundUplink\": true,
      \"statsInboundDownlink\": true,
      \"statsOutboundUplink\" : true,
      \"statsOutboundDownlink\" : true
    }
  }
}"
# Menambahkan konfigurasi ke dalam file Xray
echo "$TEXT" >> "$XRAY_CONFIG"

# Reload dan restart Xray service
systemctl daemon-reload
systemctl restart xray@xhttp

clear
echo ""
echo ""
echo ""
echo -e "Success Back To Default Routing"
}

restore-route() {
while true; do
    read -p "Are you sure you want to do a Restore? (y/n): " opw || exit 0
    case $opw in
        y|Y)
            echo "Proceeding with Restore..."
            resd
            break
            ;;
        n|N)
            echo "Exiting..."
            exit 1
            ;;
        *)
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
    esac
done

}

addroute() {
echo -e "
${separator}
[ Add Routing XRAY WS ]
${separator}

1. Vmess
2. Vless
3. Trojan
${blue_sep}
 Press CTRL + C to Exit
${separator}
"
read -p "Input Your Routing Protocol: " prot || exit 0
case $prot in
1) clear ; vmessjir ;;
2) clear ; vlessjir ;;
3) clear ; trojanjir ;;
*) clear ; addroute ;;
esac
}

addrules() {
echo -e "
${separator}
[ Menu Rules XRAY ]
${separator}

1. Add Rules Domain
${separator}
"
read -p "Input Option: " op || exit 0
case $op in
1) clear ; nano /root/.rules/domain ;;
*) clear ; addrules ;;
esac
}

menu-rout() {
clear
echo ""
echo ""
echo ""
echo -e "
${separator}
[ Menu Routing WS ]
${separator}

1. Add Account
2. Create Rules
3. Back To Default Routing
4. Back To Menu
${blue_sep}
Press CTRL + C to Exit
${separator}
"
read -p "Input Option: " aws || exit 0
case $aws in
1) clear ; addroute ;;
2) clear ; addrules ;;
3) clear ; restore-route ;;
4) menu ;;
*) menu-rout ;;
esac
}

menu-rout
