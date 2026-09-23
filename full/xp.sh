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

systemctl daemon-reload
clear

##----- Auto Remove Xray / V2ray Websocket
data=( `cat /etc/v2ray/config.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/v2ray/config.json" | cut -d ' ' -f 3 | sort | uniq)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
sed -i "/### $user $exp/ {N;d}" /etc/v2ray/config.json
        rm -f /var/log/create/xray/ws/${user}.log
        rm -f /etc/xray/quota/ws/$user*
        rm -f /etc/xray/limit/ip/xray/ws/$user
TEKS="
====================
X-Ray WS Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
clear
systemctl daemon-reload
systemctl restart v2ray
fi
done

##----- Auto Remove Xray / V2ray HTTP UPGRADE
data=( `cat /etc/xray/json/upgrade.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/upgrade.json" | cut -d ' ' -f 3 | sort | uniq)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
sed -i "/### $user $exp/ {N;d}" /etc/xray/json/upgrade.json
        rm -f /var/log/create/xray/http/${user}.log
        rm -f /etc/xray/quota/http/$user*
        rm -f /etc/xray/limit/ip/xray/http/$user
TEKS="
====================
X-Ray http Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
clear
systemctl daemon-reload
systemctl restart xray@upgrade
fi
done

##----- Auto Remove Xray / V2ray Split HTTP
data=( `cat /etc/xray/json/split.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/split.json" | cut -d ' ' -f 3 | sort | uniq)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
sed -i "/### $user $exp/ {N;d}" /etc/xray/json/split.json
        rm -f /var/log/create/xray/split/${user}.log
        rm -f /etc/xray/quota/split/$user*
        rm -f /etc/xray/limit/ip/xray/split/$user
TEKS="
====================
X-Ray split Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
clear
systemctl daemon-reload
systemctl restart xray@split
fi
done

##----- Auto Remove Xray / V2ray grpc HTTP
data=( `cat /etc/xray/json/grpc.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/grpc.json" | cut -d ' ' -f 3 | sort | uniq)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
sed -i "/### $user $exp/ {N;d}" /etc/xray/json/grpc.json
        rm -f /var/log/create/xray/grpc/${user}.log
        rm -f /etc/xray/quota/grpc/$user*
        rm -f /etc/xray/limit/ip/xray/grpc/$user
TEKS="
====================
X-Ray grpc Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
clear
systemctl daemon-reload
systemctl restart xray@grpc
fi
done


##------ Auto Remove SSH
hariini=`date +%d-%m-%Y`
cat /etc/shadow | cut -d: -f1,8 | sed /:$/d > /tmp/expirelist.txt
totalaccounts=`cat /tmp/expirelist.txt | wc -l`
for((i=1; i<=$totalaccounts; i++ ))
do
tuserval=`head -n $i /tmp/expirelist.txt | tail -n 1`
username=`echo $tuserval | cut -f1 -d:`
userexp=`echo $tuserval | cut -f2 -d:`
userexpireinseconds=$(( $userexp * 86400 ))
tglexp=`date -d @$userexpireinseconds`             
tgl=`echo $tglexp |awk -F" " '{print $3}'`
while [ ${#tgl} -lt 2 ]
do
tgl="0"$tgl
done
bulantahun=`echo $tglexp |awk -F" " '{print $2,$6}'`
todaystime=`date +%s`
if [ $userexpireinseconds -ge $todaystime ] ;
then
:
else
userdel --force $username
rm -fr /etc/xray/limit/ip/ssh/$username
systemctl daemon-reload
systemctl restart ssh
systemctl restart sshd
systemctl restart ws
systemctl restart dropbear
TEKS="
====================
SSH Account Expired
====================

-> $username / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
rm -rf /etc/funny/limit/ssh/ip/$user
clear
fi
done

# L2TP
clear
data=( `cat /etc/funny/.l2tp | grep '^###' | cut -d ' ' -f 2`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/funny/.l2tp" | cut -d ' ' -f 3)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
sed -i "/^### $user $exp/d" "/etc/funny/.l2tp"
sed -i '/^"'"$user"'" l2tpd/d' /etc/ppp/chap-secrets
sed -i '/^'"$user"':\$1\$/d' /etc/ipsec.d/passwd
TEKS="
====================
L2TP Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid)
KEY=$(cat /etc/funny/.keybot)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
systemctl restart ipsec
systemctl restart xl2tpd
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
fi
done

# WIREGUARD
if [[ -f /etc/funny/.wireguard ]]; then
while read expired; do
	user=$(echo $expired | awk '{print $1}')
	exp=$(echo $expired | awk '{print $2}')

	if [[ $exp < $now ]]; then
		sed -i "/^### Client ${user}\$/,/^$/d" /etc/wireguard/wg0.conf
		if grep -q "### Client" /etc/wireguard/wg0.conf; then
			line=$(grep -n AllowedIPs /etc/wireguard/wg0.conf | tail -1 | awk -F: '{print $1}')
			head -${line} /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		else
			head -6 /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		fi
		rm -f /var/www/html/wireguard-${user}.conf
		sed -i "/\b$user\b/d" /etc/funny/.wireguard
        TEKS="
        ====================
        WG Account Expired
        ====================

        -> $user / $exp
        ===================="
        CHATID=$(cat /etc/funny/.chatid)
        KEY=$(cat /etc/funny/.keybot)
        TIME="10"
        URL="https://api.telegram.org/bot$KEY/sendMessage"
        curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
	fi
done < /etc/funny/.wireguard
fi

# Noobz
# <- Noobz Expired -> 
# // Membersihkan layar
clear

# // Ini Adalah Auto Expired Untuk Noobzvpns

# Membaca Akun Yang Aktif
data=($(grep '^###' /etc/funny/.noob | awk '{print $2}' | sort | uniq))

# Tahun-Bulan-Tanggal hari ini
now=$(date +"%Y-%m-%d")

# Mendefinisikan Bahwa user = data
for user in "${data[@]}"; do
    # Membaca Masa Aktif Username
    exp=$(grep -w "^### $user" /etc/funny/.noob | awk '{print $3}' | sort | uniq) 
    
    # Menampilkan Masa Aktif Sesuai Username
    d1=$(date -d "$exp" +%s) 
    d2=$(date -d "$now" +%s) 
    
    # Menghitung selisih hari
    exp2=$(( (d1 - d2) / 86400 )) 
    
    # Jika masa aktif sudah habis
    if [[ "$exp2" -le "0" ]]; then
        # Menghapus pengguna dari file dan sistem
        sed -i "/^### $user $exp/d" /etc/funny/.noob
        noobzvpns remove "$user"
        
        # Menyiapkan teks untuk notifikasi
        TEKS="
════════════════════════════
Username Expired
════════════════════════════

User: $user
Exp : $exp
════════════════════════════
"
        # Mengambil CHATID dan KEY dari file
        CHATID=$(cat /etc/funny/.chatid)
        KEY=$(cat /etc/funny/.keybot)
        TIME="10"
        URL="https://api.telegram.org/bot$KEY/sendMessage"

        # Mengirim notifikasi ke Telegram
        response=$(curl -s --max-time $TIME -d "chat_id=$CHATID&text=$TEKS" $URL)
        systemctl restart noobzvpns
        # Memeriksa apakah pengiriman berhasil
        if [[ $(echo "$response" | jq -r '.ok') == "true" ]]; then
            clear
            echo "$TEKS"
        else
            echo "Gagal mengirim notifikasi ke Telegram."
            echo "Response: $response"
        fi
    fi
done
