#!/bin/bash
# Found 525: license is enforced only for create/extend/install.

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
echo ""
echo ""
# Function Bytes Quota
function bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.2f KB\n" "$(bc -l <<< "scale=2; $bytes/1024")"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.2f MB\n" "$(bc -l <<< "scale=2; $bytes/1048576")"
    elif [[ $bytes -lt 1099511627776 ]]; then
        printf "%.2f GB\n" "$(bc -l <<< "scale=2; $bytes/1073741824")"
    elif [[ $bytes -lt 1125899906842624 ]]; then
        printf "%.2f TB\n" "$(bc -l <<< "scale=2; $bytes/1099511627776")"
    else
        printf "%.2f PB\n" "$(bc -l <<< "scale=2; $bytes/1125899906842624")"
    fi
}

clear
echo ""
echo ""
RSEP='[38;2;255;0;0m-[38;2;255;45;0m-[38;2;255;90;0m-[38;2;255;135;0m-[38;2;255;180;0m-[38;2;255;225;0m-[38;2;240;255;0m-[38;2;195;255;0m-[38;2;150;255;0m-[38;2;105;255;0m-[38;2;60;255;0m-[38;2;15;255;0m-[38;2;0;255;30m-[38;2;0;255;75m-[38;2;0;255;120m-[38;2;0;255;165m-[38;2;0;255;210m-[38;2;0;255;255m-[38;2;0;210;255m-[38;2;0;165;255m-[38;2;0;120;255m-[38;2;0;75;255m-[38;2;0;30;255m-[38;2;15;0;255m-[38;2;60;0;255m-[38;2;105;0;255m-[38;2;150;0;255m-[38;2;195;0;255m-[38;2;240;0;255m-[38;2;255;0;225m-[38;2;255;0;180m-[38;2;255;0;135m-[38;2;255;0;90m-[38;2;255;0;45m-[38;2;255;0;0m-[0m'
echo -e "$RSEP"
echo -e "      XTLS XHTTP ACCOUNT LIST"
echo -e "$RSEP"
> /var/log/xray/accsess.log

# Numbered user list, like Check Database Logs (option 10)
data=( $(ls /var/log/create/xray/xhttp/ | sed -E 's/\.(locked|log)$//' | sort -u) )

if [ ${#data[@]} -eq 0 ]; then
    echo -e "No active accounts found."
    echo -e "$RSEP"
    exit 0
fi

i=1
for u in "${data[@]}"; do
    printf "\e[32;1m%02d\e[0m. %s\n" "$i" "$u"
    i=$((i+1))
done
echo -e "\033[1;34m-----------------------------------\033[0m"
echo -e "Total Accounts: ${#data[@]}"
echo -e "\033[1;34m-----------------------------------\033[0m"
echo -e "\033[38;5;208mPress [Ctrl + C] to exit\033[0m"
echo -e "$RSEP"
read -p "Input Username or number: " input || exit 0

# A number picks from the list, a name is used as-is
user="$input"
if [[ "$input" =~ ^[0-9]+$ ]]; then
    n=$((10#$input))
    if [ "$n" -ge 1 ] && [ "$n" -le "${#data[@]}" ]; then
        user="${data[$((n-1))]}"
    fi
fi

if [[ -f /var/log/create/xray/xhttp/${user}.locked ]]; then
    status="locked"
elif [[ -f /var/log/create/xray/xhttp/${user}.log ]]; then
    status="unlocked"
else
    echo -e "\e[31;1mUser not found: $input\e[0m"
    exit 0
fi

if [[ "$status" == "locked" ]]; then
    echo -e "\e[33;1mUser\e[32;1m: $user"
    echo -e "\e[33;1mStatus Account XRAY\e[32;1m: $status"
    echo -e "$RSEP"
fi

if [[ "$status" == "unlocked" ]]; then
    limip=$(grep "Limit IP:" /var/log/create/xray/xhttp/${user}.log | awk '{print $3}')
    top=$(cat /etc/xray/quota/xhttp/$user 2>/dev/null || echo 0)
    quota=$(bytes "$top")
    uid=$(grep -F "\"email\": \"${user}\"" /etc/xray/json/xhttp.json | sed -nE 's/.*"(id|password)": "([^"]+)".*/\2/p' | sort -u | head -1)
    protokol=$(grep -E "^(Protokol|Protocol) *:" /var/log/create/xray/xhttp/${user}.log | awk '{print $NF}')
    protokol=${protokol^^}
    exp=$(grep "Expired" /var/log/create/xray/xhttp/${user}.log | awk '{print $3}')
    echo -e "\e[33;1mUser\e[32;1m: $user"
    echo -e "\e[33;1mExpired\e[32;1m: $exp"
    echo -e "\e[33;1mLimit IP\e[32;1m: $limip"
    echo -e "\e[33;1mLimit Quota\e[32;1m: $quota"
    echo -e "\e[33;1mUUID / Password\e[32;1m: $uid"
    echo -e "\e[33;1mProtocol Account\e[32;1m: $protokol"
    echo -e "\e[33;1mStatus Account XRAY\e[32;1m: $status"
    echo -e "$RSEP"
fi
