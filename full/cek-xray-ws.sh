#!/bin/bash

# Color constants
GREEN="\033[32;1m"
NC="\033[0m"
BLUE="\033[0;34m"

# Log file path
log_path="/var/log/xray/ws.log"

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
    # Nothing has connected since the log was last cleared. This is a normal
    # state, so return success like the Go cek tools do (it is not an error).
    echo "No active users found!"
    exit 0
fi

# Process each active user
for user in "${users[@]}"; do
    # Filter logs for the user
    logs=$(grep "email: $user" "$log_path")
    
    # Count unique client IPs. Bug 101: the access line starts with the date, so
    # $1 is the day; the address is the token after "from" (`<ip>:<port>`), which
    # is the X-Forwarded-For address nginx supplies.
    ip_count=$(echo "$logs" | awk '{for(i=1;i<=NF;i++) if($i=="from"){print $(i+1); break}}' | sed 's/:[0-9]*$//' | sed '/^$/d' | sort -u | wc -l)

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

    # Traffic stats (uplink and downlink). Bug 100: `xray api stats` requires an
    # explicit -name and errors without one; read both counters via statsquery
    # (patterns also stop one username from matching another). Counters are bytes.
    uplink=$(xray api statsquery --server=127.0.0.1:10080 -pattern "user>>>${user}>>>traffic>>>uplink" 2>/dev/null | jq -r '.stat[0].value // 0' 2>/dev/null)
    downlink=$(xray api statsquery --server=127.0.0.1:10080 -pattern "user>>>${user}>>>traffic>>>downlink" 2>/dev/null | jq -r '.stat[0].value // 0' 2>/dev/null)
    echo "Traffic Uplink: ${uplink:-0} bytes ($(format_bytes "${uplink:-0}"))"
    echo "Traffic Downlink: ${downlink:-0} bytes ($(format_bytes "${downlink:-0}"))"
    echo "Quota: $quota"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━${NC}"
done

echo -n > /var/log/xray/ws.log