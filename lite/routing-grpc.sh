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
clear

trojanjir() {
echo -e "
==================
[ Routing Seting ]
==================
Only X-Ray Trojan WebSocket TLS Routing
=================="
read -p $'\033[96;1mInput Name: \033[0m' names
read -p $'\033[96;1mInput Domain: \033[0m' domain
read -p $'\033[96;1mInput Port: \033[0m' port
read -p $'\033[96;1mInput Password: \033[0m' password
read -p $'\033[96;1mInput Path: \033[0m' path
clear
DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/grpc.json"

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
line=$(cat /etc/xray/json/grpc.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/grpc.json

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
systemctl restart xray@grpc

clear
echo -e "Routing Success With Trojan WebSocket TLS"
}

vlessjir() {
echo -e "
==================
[ Routing Seting ]
==================
Only X-Ray Vless None TLS
=================="
read -p $'\033[96;1mInput Name: \033[0m' names
read -p $'\033[96;1mInput Domain: \033[0m' domain
read -p $'\033[96;1mInput Port: \033[0m' port
read -p $'\033[96;1mInput UUID: \033[0m' uid
read -p $'\033[96;1mInput Path: \033[0m' path
clear
DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/grpc.json"

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
line=$(cat /etc/xray/json/grpc.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/grpc.json

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
systemctl restart xray@grpc

clear
echo -e "Routing Success With All Protocol X-Ray WebSocket using Xray Vless WS NoneTLS"
}

vmessjir() {
echo -e "
==================
[ Routing Setting ]
==================
Only X-Ray VMESS None TLS
=================="

read -p $'\033[96;1mInput Name: \033[0m' names
read -p $'\033[96;1mInput Domain: \033[0m' domain
read -p $'\033[96;1mInput Port: \033[0m' port
read -p $'\033[96;1mInput UUID: \033[0m' uid
read -p $'\033[96;1mInput Path: \033[0m' path
clear

DOMAIN_FILE="/root/.rules/domain"
XRAY_CONFIG="/etc/xray/json/grpc.json"

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
line=$(cat /etc/xray/json/grpc.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/grpc.json

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
systemctl restart xray@grpc

clear
echo -e "Routing Success With All Protocol X-Ray VMESS WebSocket Non-TLS"
}



resd() {
# Mengambil Lokasi Xray Config
XRAY_CONFIG="/etc/xray/json/grpc.json"

# Mendapatkan nomor baris untuk bagian "outbounds"
line=$(cat /etc/xray/json/grpc.json | grep -n '"outbounds":' | awk -F: '{print $1}' | head -1)

# Menghapus bagian setelah "outbounds"
sed -i "${line},\$d" /etc/xray/json/grpc.json
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
systemctl restart xray@grpc

clear
echo -e "Success Back To Default Routing"
}

restore-route() {
while true; do
    read -p $'\033[96;1mAre you sure you want to do a Restore? (y/n): \033[0m' opw
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
==========================
[ Add Routing X-Ray gRPC ]
==========================

1. Vmess
2. Vless
3. Trojan
==========================
 Press CTRL + C to Exit
==========================
"
read -p $'\033[96;1mInput Your Routing Protocol: \033[0m' prot
case $prot in
1) clear ; vmessjir ;;
2) clear ; vlessjir ;;
3) clear ; trojanjir ;;
*) clear ; addroute ;;
esac
}

addrules() {
echo -e "
====================
[ Menu Rules X-Ray ]
====================

1. Add Rules Domain
====================
"
read -p $'\033[96;1mInput Option: \033[0m' op
case $op in
1) clear ; nano /root/.rules/domain ;;
*) clear ; addrules ;;
esac
}

menu-rout() {
clear
echo -e "
=====================
[ Menu Routing gRPC ]
=====================

1. Add Account
2. Create Rules
3. Back To Default Routing
4. Back To Menu
=====================
Press CTRL + C to Exit
=====================
"
read -p $'\033[96;1mInput Option: \033[0m' aws
case $aws in
1) clear ; addroute ;;
2) clear ; addrules ;;
3) clear ; restore-route ;;
4) menu ;;
*) menu-rout ;;
esac
}

menu-rout
