#!/bin/bash
# Terminal display formatter matching Go log viewer styling
# Rainbow outer seps, blue inner seps, purple headers, green values,
# white Link labels with deep purple URLs
format_display() {
    local text="$1"
    local reset=$'\033[0m'
    local green=$'\033[0;32m'
    local blue=$'\033[1;34m'
    local purple=$'\033[1;35m'
    local dpurple=$'\033[38;5;141m'
    local -a sep_lines=() all_lines=()
    local idx=0
    while IFS= read -r line; do
        local t="${line#"${line%%[![:space:]]*}"}"
        [[ "$t" =~ ^[=]{3,}$ ]] && sep_lines+=($idx)
        all_lines+=("$line")
        ((idx++))
    done <<< "$text"
    local total=${#all_lines[@]}
    local nseps=${#sep_lines[@]}
    local first_sep=${sep_lines[0]:-999}
    local last_sep=999
    if (( nseps > 0 )); then
        last_sep=${sep_lines[$((nseps-1))]:-999}
    fi
    for ((i=0; i<total; i++)); do
        local line="${all_lines[$i]}"
        local trimmed="${line#"${line%%[![:space:]]*}"}"
        if [[ "$trimmed" =~ ^[=]{3,}$ ]]; then
            if [[ $i -eq $first_sep || $i -eq $last_sep ]]; then
                local len=${#trimmed} out=""
                for ((c=0; c<len; c++)); do
                    local r=$((c*360/len))
                    if ((r<60)); then out+="\033[38;2;255;$((r*255/60));0m="
                    elif ((r<120)); then out+="\033[38;2;$(((120-r)*255/60));255;0m="
                    elif ((r<180)); then out+="\033[38;2;0;255;$(((r-120)*255/60))m="
                    elif ((r<240)); then out+="\033[38;2;0;$(((240-r)*255/60));255m="
                    elif ((r<300)); then out+="\033[38;2;$(((r-240)*255/60));0;255m="
                    else out+="\033[38;2;255;0;$(((360-r)*255/60))m="; fi
                done
                echo -e "${out}${reset}"
            else
                echo -e "${blue}${trimmed}${reset}"
            fi
        else
            local ps=0 ns=0
            if ((i>0)); then
                local pt="${all_lines[$((i-1))]}"
                pt="${pt#"${pt%%[![:space:]]*}"}"
                [[ "$pt" =~ ^[=]{3,}$ ]] && ps=1
            fi
            if ((i<total-1)); then
                local nt="${all_lines[$((i+1))]}"
                nt="${nt#"${nt%%[![:space:]]*}"}"
                [[ "$nt" =~ ^[=]{3,}$ ]] && ns=1
            fi
            if ((ps && ns)) && [[ ! "$trimmed" =~ ^Link\  ]]; then
                echo -e "${purple}${trimmed}${reset}"
            elif [[ "$trimmed" =~ ^Link\  ]] && [[ "$line" == *:* ]]; then
                local key="${line%%:*}" val="${line#*:}"
                echo -e "${key}:${dpurple}${val}${reset}"
            elif [[ "$line" == *:* ]] && \
                 [[ ! "$trimmed" =~ ^vmess:// ]] && \
                 [[ ! "$trimmed" =~ ^vless:// ]] && \
                 [[ ! "$trimmed" =~ ^trojan:// ]] && \
                 [[ ! "$trimmed" =~ ^http:// ]] && \
                 [[ ! "$trimmed" =~ ^https:// ]]; then
                local key="${line%%:*}" val="${line#*:}"
                echo -e "${key}:${green}${val}${reset}"
            else
                echo -e "$line"
            fi
        fi
    done
}
