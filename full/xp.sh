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

systemctl daemon-reload
clear

# Deletions are destructive and were previously silent; keep an audit line so a
# vanished account can always be attributed to xp.
xp_log() { echo "$(date '+%F %T') xp: $*" >> /etc/xray/.quota.logs; }

##----- Auto Remove Xray Websocket
data=( `cat /etc/xray/json/ws.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
ws_expired=0
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/ws.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo "Skipping $user: unparseable expiry '$exp'"
    continue
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
    xp_log "deleted $user (expiry $exp)"
sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/ws.json
sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/ws.json
        rm -f /var/log/create/xray/ws/${user}.log
        rm -f /etc/xray/quota/ws/$user /etc/xray/quota/ws/${user}_usage
        rm -f /etc/xray/limit/ip/xray/ws/$user
TEKS="
====================
X-Ray WS Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
ws_expired=1
fi
done
if [[ $ws_expired -eq 1 ]]; then
    if xray run -test -config /etc/xray/json/ws.json >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl restart xray@ws
    fi
fi

##----- Auto Remove Xray HTTP UPGRADE
http_expired=0
data=( `cat /etc/xray/json/upgrade.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/upgrade.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo "Skipping $user: unparseable expiry '$exp'"
    continue
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
    xp_log "deleted $user (expiry $exp)"
sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/upgrade.json
sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/upgrade.json
        rm -f /var/log/create/xray/http/${user}.log
        rm -f /etc/xray/quota/http/$user /etc/xray/quota/http/${user}_usage
        rm -f /etc/xray/limit/ip/xray/http/$user
TEKS="
====================
X-Ray http Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
http_expired=1
fi
done
if [[ $http_expired -eq 1 ]]; then
    if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl restart xray@upgrade
    fi
fi

##----- Auto Remove Xray Split HTTP
split_expired=0
data=( `cat /etc/xray/json/split.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/split.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo "Skipping $user: unparseable expiry '$exp'"
    continue
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
    xp_log "deleted $user (expiry $exp)"
sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/split.json
sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/split.json
        rm -f /var/log/create/xray/split/${user}.log
        rm -f /etc/xray/quota/split/$user /etc/xray/quota/split/${user}_usage
        rm -f /etc/xray/limit/ip/xray/split/$user
TEKS="
====================
X-Ray split Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
split_expired=1
fi
done
if [[ $split_expired -eq 1 ]]; then
    if xray run -test -config /etc/xray/json/split.json >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl restart xray@split
    fi
fi

##----- Auto Remove Xray grpc HTTP
grpc_expired=0
data=( `cat /etc/xray/json/grpc.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/xray/json/grpc.json" | cut -d ' ' -f 3 | sort | uniq | head -n 1)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo "Skipping $user: unparseable expiry '$exp'"
    continue
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
    xp_log "deleted $user (expiry $exp)"
sed -i "/^### $user $exp/ {N;d}" /etc/xray/json/grpc.json
sed -i -z 's/},\n *\]/}\n        ]/g' /etc/xray/json/grpc.json
        rm -f /var/log/create/xray/grpc/${user}.log
        rm -f /etc/xray/quota/grpc/$user /etc/xray/quota/grpc/${user}_usage
        rm -f /etc/xray/limit/ip/xray/grpc/$user
TEKS="
====================
X-Ray grpc Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
grpc_expired=1
fi
done
if [[ $grpc_expired -eq 1 ]]; then
    if xray run -test -config /etc/xray/json/grpc.json >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl restart xray@grpc
    fi
fi

##------ Auto Remove SSH
hariini=`date +%d-%m-%Y`
cat /etc/shadow | cut -d: -f1,8 | sed /:$/d > /tmp/expirelist.txt
totalaccounts=`cat /tmp/expirelist.txt | wc -l`
ssh_expired=0
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
rm -f /var/log/create/ssh/${username}.log
exp="$tgl $bulantahun"
xp_log "deleted $username (expiry $exp)"
ssh_expired=1
TEKS="
====================
SSH Account Expired
====================

-> $username / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
clear
fi
done
if [[ $ssh_expired -eq 1 ]]; then
    systemctl daemon-reload
    systemctl restart ssh
    systemctl restart sshd
    systemctl restart ws
    systemctl restart dropbear 2>/dev/null || true
fi

# L2TP
clear
l2tp_expired=0
data=( `cat /etc/funny/.l2tp | grep '^###' | cut -d ' ' -f 2`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
exp=$(grep -w "^### $user" "/etc/funny/.l2tp" | cut -d ' ' -f 3)
d1=$(date -d "$exp" +%s 2>/dev/null)
if [ -z "$d1" ]; then
    echo "Skipping $user: unparseable expiry '$exp'"
    continue
fi
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
if [[ "$exp2" -le "0" ]]; then
    xp_log "deleted $user (expiry $exp)"
sed -i "/^### $user $exp/d" "/etc/funny/.l2tp"
sed -i '/^"'"$user"'" l2tpd/d' /etc/ppp/chap-secrets
sed -i '/^'"$user"':/d' /etc/ipsec.d/passwd
TEKS="
====================
L2TP Account Expired
====================

-> $user / $exp
===================="
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
TIME="10"
URL="https://api.telegram.org/bot$KEY/sendMessage"
curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
l2tp_expired=1
fi
done
if [[ $l2tp_expired -eq 1 ]]; then
    systemctl restart ipsec 2>/dev/null || true
    systemctl restart xl2tpd 2>/dev/null || true
    chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.l2tp 2>/dev/null || true
fi

# WIREGUARD
if [[ -f /etc/funny/.wireguard ]]; then
    now=$(date +"%Y-%m-%d")
wg_restarted=0
while read expired; do
	user=$(echo $expired | awk '{print $1}')
	exp=$(echo $expired | awk '{print $2}')

	if [ -n "$exp" ] && [[ "$exp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ ! $now < $exp ]]; then
	xp_log "deleted wireguard client $user (expiry $exp)"
		awk "/^### Client ${user}$/{found=1} found && /^$/{found=0; next} !found{print} found{next}" \
			/etc/wireguard/wg0.conf > /tmp/wg0.conf && mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		chmod 600 /etc/wireguard/wg0.conf 2>/dev/null || true
		rm -f /var/www/html/wireguard-${user}.conf
		sed -i "/\b$user\b/d" /etc/funny/.wireguard
        TEKS="
        ====================
        WG Account Expired
        ====================

        -> $user / $exp
        ===================="
        CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
        KEY=$(cat /etc/funny/.keybot 2>/dev/null)
        TIME="10"
        URL="https://api.telegram.org/bot$KEY/sendMessage"
        curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL
        wg_restarted=1
	fi
done < /etc/funny/.wireguard
if [ "$wg_restarted" = "1" ]; then
    systemctl daemon-reload
    systemctl restart wg-quick@wg0 2>/dev/null || true
fi
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
noobz_restarted=0

# Mendefinisikan Bahwa user = data
for user in "${data[@]}"; do
    # Membaca Masa Aktif Username
    exp=$(grep -w "^### $user" /etc/funny/.noob | awk '{print $3}' | sort | uniq | head -n 1) 
    
    # Menampilkan Masa Aktif Sesuai Username
    d1=$(date -d "$exp" +%s 2>/dev/null)
    if [ -z "$d1" ]; then
        echo "Skipping $user: unparseable expiry '$exp'"
        continue
    fi
    d2=$(date -d "$now" +%s)
    
    # Menghitung selisih hari
    exp2=$(( (d1 - d2) / 86400 )) 
    
    # Jika masa aktif sudah habis
    if [[ "$exp2" -le "0" ]]; then
        xp_log "deleted $user (expiry $exp)"
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
        CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
        KEY=$(cat /etc/funny/.keybot 2>/dev/null)
        TIME="10"
        URL="https://api.telegram.org/bot$KEY/sendMessage"

        # Mengirim notifikasi ke Telegram
        response=$(curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL)
        noobz_restarted=1
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
if [ "$noobz_restarted" -eq 1 ]; then
    systemctl daemon-reload
    systemctl restart noobzvpns 2>/dev/null || true
fi
