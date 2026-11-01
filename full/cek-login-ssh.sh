#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

    # Auth sources race: same izin.txt on Pages + GitHub (synced), first valid reply wins; no primary/secondary.
    PERMISSION_CFPAGES="https://fn-autosc-auth.pages.dev/izin.txt"
    PERMISSION_GITHUB="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
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
        # Fetch both auth sources at once; first complete valid reply wins (OR logic).
    PERMISSION_TMP=$(mktemp -d) || { echo "Failed to download permissions."; exit 1; }
    (curl -s --max-time 12 "$PERMISSION_CFPAGES" -o "$PERMISSION_TMP/a" 2>/dev/null; touch "$PERMISSION_TMP/a.done") &
    (curl -s --max-time 12 "$PERMISSION_GITHUB" -o "$PERMISSION_TMP/b" 2>/dev/null; touch "$PERMISSION_TMP/b.done") &
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
        REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE") || { echo "Permission data invalid."; exit 1; }
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
# General TUI theme (same as menu-ssh / x-ws)
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

echo -e "${NC}${separator}
          SSH USER LOGIN
${separator}"


# Found 512: the old table counted every historical "Password auth succeeded"
# line (10,000 journal lines / the whole auth.log) and printed it as the login
# count.  That is why an account with one real client IP could show 3/2, 6/2,
# or 481/2.  Use the same active-session view as limit-ip-ssh: unique real
# client IPs per account, including WS/CDN sessions mapped by ssh-online.
SSH_ONLINE_BIN="${SSH_ONLINE_BIN:-$(command -v ssh-online 2>/dev/null || true)}"
if [ -z "$SSH_ONLINE_BIN" ] || [ ! -x "$SSH_ONLINE_BIN" ]; then
    echo "ssh-online helper not found; run update.sh to install it." >&2
    exit 1
fi

SSH_ONLINE=$(mktemp) || { echo "Cannot create temporary file." >&2; exit 1; }
trap 'rm -f "$SSH_ONLINE"' EXIT
if ! "$SSH_ONLINE_BIN" > "$SSH_ONLINE" 2>/dev/null; then
    echo "ssh-online failed; cannot read active SSH sessions." >&2
    exit 1
fi

# Fungsi untuk mendapatkan Limit IP dari file tertentu
function get_limit_ip {
    USER=$1
    LIMIT_FILE="/etc/xray/limit/ip/ssh/$USER"

    if [ -f "$LIMIT_FILE" ]; then
        LIMIT=$(cat "$LIMIT_FILE")
        if [ "$LIMIT" == "Unlimited" ]; then
            echo "Unlimited"
        else
            echo "$LIMIT"
        fi
    else
        echo "No Limit"
    fi
}

# One row per user: unique active client IPs and the daemon(s) used.
declare -A ip_seen=()
declare -A ip_count=()
declare -A user_types=()
unresolved=0
while IFS=$'\t' read -r _user _ip _kind _pid; do
    [ -n "$_user" ] || continue
    id "$_user" &>/dev/null || continue  # skip names with no account
    if [ "$_ip" = "127.0.0.1" ] && [ "$_kind" = "Dropbear" ]; then
        unresolved=$((unresolved+1))
    fi
    if [ -z "${ip_seen["$_user|$_ip"]+x}" ]; then
        ip_seen["$_user|$_ip"]=1
        ip_count["$_user"]=$(( ${ip_count["$_user"]:-0} + 1 ))
    fi
    case " ${user_types["$_user"]:-} " in
        *" $_kind "*) ;;
        *) user_types["$_user"]="${user_types["$_user"]:+${user_types["$_user"]}+}$_kind" ;;
    esac
done < "$SSH_ONLINE"

function show_logins {
    local rows=() user LIMIT_IP l wu=8 wl=5 fmt
    local -a users
    mapfile -t users < <(printf '%s\n' "${!ip_count[@]}" | sort)
    for user in "${users[@]}"; do
        [ -n "$user" ] || continue
        LIMIT_IP=$(get_limit_ip "$user" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        l="${ip_count[$user]} / ${LIMIT_IP}"
        rows+=("${user}|${l}|${user_types[$user]}")
        (( ${#user} > wu )) && wu=${#user}
        (( ${#l} > wl )) && wl=${#l}
    done
    fmt="%-${wu}s    %-${wl}s    %s\n"
    echo -e "${purple}Unique active client IPs (same view as limit-ip-ssh)${NC}"
    # shellcheck disable=SC2059
    printf "${purple}${fmt}${NC}" "Username" "IP" "Type"
    echo -e "${blue_sep}"
    for r in ${rows[@]+"${rows[@]}"}; do
        printf "$fmt" "${r%%|*}" "$(echo "$r" | cut -d'|' -f2)" "${r##*|}"
    done
    if [ "$unresolved" -gt 0 ]; then
        echo ""
        echo -e "${orange}Warning: ${unresolved} Dropbear session(s) still show 127.0.0.1 (WS/HAProxy mapping unavailable).${NC}"
        echo -e "${orange}They share one IP in this table, the same as limit-ip-ssh.${NC}"
    fi
    echo ""
}

function show_total_users {
    local total_users
    total_users=${#ip_count[@]}
    echo -e "${separator}
${purple}Total Active Users: ${green}${total_users}${NC}
${separator}"
}

show_logins
show_total_users
