#!/bin/bash

# Color constants
GREEN="\033[32;1m"
NC="\033[0m"
BLUE="\033[0;34m"

# Log file path
log_path="/var/log/v2ray/access.log"

# Check if log file exists
if [[ ! -f "$log_path" ]]; then
    echo "Log file $log_path not found!"
    exit 1
fi

# Function to format bytes into human-readable strings
format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt $((1024 * 1024)) ]]; then
        echo "$(bc <<< "scale=2; $bytes/1024") KB"
    elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
        echo "$(bc <<< "scale=2; $bytes/(1024*1024)") MB"
    elif [[ $bytes -lt $((1024 * 1024 * 1024 * 1024)) ]]; then
        echo "$(bc <<< "scale=2; $bytes/(1024*1024*1024)") GB"
    else
        echo "$(bc <<< "scale=2; $bytes/(1024*1024*1024*1024)") TB"
    fi
}

# Header
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Log X-Ray WebSocket  "
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Load users from log
users=($(grep "email:" "$log_path" | awk '{print $NF}' | cut -d':' -f2 | sort -u))

if [[ ${#users[@]} -eq 0 ]]; then
    echo "No active users found!"
    exit 1
fi

# Process each active user
for user in "${users[@]}"; do
    # Filter logs for the user
    logs=$(grep "email: $user" "$log_path")
    
    # Count unique IPs
    ip_count=$(echo "$logs" | awk '{print $1}' | sort -u | wc -l)

    # IP limit
    ip_limit=$(cat "/etc/xray/limit/ip/xray/ws/${user}")
    if [[ -z "$ip_limit" ]]; then
        ip_limit="Not available"
    fi
      
    # Quota usage and limit
    quota_usage=$(cat "/etc/xray/quota/ws/${user}_usage")
    quota_limit=$(cat "/etc/xray/quota/ws/${user}")
    if [[ -z "$quota_usage" || -z "$quota_limit" ]]; then
        quota="Not available"
    else
        quota="$(format_bytes $quota_usage) / $(format_bytes $quota_limit)"
    fi

    # Display user details
    echo -e "\n${NC}Username: ${GREEN}${user}${NC}"
    echo "Total IP Login: $ip_count / $ip_limit"

    # Protocol (if available in custom logs)
    protocol_log_path="/var/log/create/xray/ws/${user}.log"
    protocol=$(grep "Protokol:" "$protocol_log_path" | awk '{print $2}' 2>/dev/null)
    [[ -z "$protocol" ]] && protocol="Not available"
    echo "Protocol Account: $protocol"

    # Traffic stats (uplink and downlink)
    uplink=$(v2ray api stats --server=127.0.0.1:10080 | grep "user>>>${user}>>>traffic>>>uplink" | awk '{print $2}')
    downlink=$(v2ray api stats --server=127.0.0.1:10080 | grep "user>>>${user}>>>traffic>>>downlink" | awk '{print $2}')
    echo "Traffic Uplink: ${uplink} connections"
    echo "Traffic Downlink: ${downlink} connections"
    echo "Quota: $quota"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━${NC}"
done

echo -n > /var/log/v2ray/access.log