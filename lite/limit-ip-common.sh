#!/bin/bash
# Found 545: CGNAT-aware simultaneous-IP sampling for the four Xray
# transports.  The transport wrapper sets:
#   TRANSPORT, TRANSPORT_LABEL, SERVICE, JSON, STATS_PORT, JSON_LOCK,
#   CARD_DIR, AUTO_DIR, STATE_DIR, UNLOCK_BIN
#
# Policy:
#   - sample every LIMIT_SAMPLE_INTERVAL seconds (default 15) for
#     LIMIT_RUN_SECONDS (default 270)
#   - an IP must be continuously present for LIMIT_ELIGIBILITY seconds
#     (default 60) before it counts
#   - lock after LIMIT_CONFIRM seconds (default 300) of continuous
#     over-limit
#   - clear the over-limit timer only after LIMIT_RESET seconds (default
#     90) at or below the limit
#   - a monitoring gap longer than LIMIT_GAP_RESET seconds (default 120)
#     clears the over-limit timer; absence of evidence is not evidence of
#     a continuous over-limit set
#
# Only the live statsonlineiplist map is used for enforcement.  The access
# log is no longer merged into the count: a replaced IP must not keep looking
# like a second login for another minute.

if [ ! -t 1 ] && [ "${LIMIT_VERBOSE:-0}" != "1" ]; then exec >/dev/null 2>&1; fi

: "${TRANSPORT:?}" "${TRANSPORT_LABEL:?}" "${SERVICE:?}" "${JSON:?}" \
  "${STATS_PORT:?}" "${JSON_LOCK:?}" "${CARD_DIR:?}" "${AUTO_DIR:?}" \
  "${STATE_DIR:?}" "${UNLOCK_BIN:?}"

SAMPLE_INTERVAL="${LIMIT_SAMPLE_INTERVAL:-15}"
RUN_SECONDS="${LIMIT_RUN_SECONDS:-270}"
ELIGIBILITY="${LIMIT_ELIGIBILITY:-60}"
CONFIRM="${LIMIT_CONFIRM:-300}"
RESET_AFTER="${LIMIT_RESET:-90}"
GAP_RESET="${LIMIT_GAP_RESET:-120}"
LIMIT_DIR="${LIMIT_DIR:-/etc/xray/limit/ip/xray/${TRANSPORT}}"

[ -f "$JSON" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v flock >/dev/null 2>&1 || exit 0

# Cron already holds /tmp/limit-ip-<transport>.lock.  This second lock only
# stops a manual run from overlapping a long sampling pass.
exec 8>"/tmp/limit-ip-${TRANSPORT}.run.lock"
flock -n 8 || exit 0

need_restart=0
declare -A _st_first=()
mkdir -p "$STATE_DIR" 2>/dev/null || true

send_log() {
    local CHATID KEY URL DATE TEXT TIME
    CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
    KEY=$(cat /etc/funny/.keybot 2>/dev/null)
    [ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
    URL="https://api.telegram.org/bot${KEY}/sendMessage"
    TIME="10"
    DATE=$(date +"%d-%b-%Y %H:%M:%S")
    TEXT="
<b>-----------------------</b>
<b>MULTILOGIN LOCKED</b>
<b>-----------------------</b>
<code>Date     : ${DATE}</code>
<code>Username : ${user}</code>
<code>Protocol : ${proto}</code>
<code>Transport: ${TRANSPORT_LABEL}</code>
<code>Login    : ${cek} / ${limit}</code>
<code>Status   : Locked</code>
<b>-----------------------</b>
${_ipline}
${_ipblock}
<b>-----------------------</b>
<i>Catatan:</i> The user account has been locked and total usage bandwidth will not be reset on the server. The account will be automatically unlocked after at least 15 minutes."
    curl -s --max-time "$TIME" -d "chat_id=${CHATID}&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=${TEXT}" "$URL" >/dev/null 2>&1
}

_state_load() {
    local key a b
    _st_over=0
    _st_below=0
    _st_last=0
    _st_first=()
    [ -f "$1" ] || return 0
    while read -r key a b; do
        case "$key" in
            v2) ;;
            over) [[ "${a:-}" =~ ^[0-9]+$ ]] && _st_over=$a ;;
            below) [[ "${a:-}" =~ ^[0-9]+$ ]] && _st_below=$a ;;
            last) [[ "${a:-}" =~ ^[0-9]+$ ]] && _st_last=$a ;;
            ip) [ -n "${a:-}" ] && [ -n "${b:-}" ] && _st_first["$a"]=$b ;;
        esac
    done < "$1"
}

_state_save() {
    local f="$1" ip tmp
    tmp="${f}.tmp.$$"
    {
        echo "v2"
        echo "over ${_st_over:-0}"
        echo "below ${_st_below:-0}"
        echo "last ${_st_last:-0}"
        for ip in "${!_st_first[@]}"; do
            echo "ip ${ip} ${_st_first[$ip]}"
        done
    } > "$tmp" 2>/dev/null && mv -f "$tmp" "$f" 2>/dev/null || rm -f "$tmp"
}

_current_ips() {
    timeout 10 xray api statsonlineiplist --server="127.0.0.1:${STATS_PORT}" -email "$1" 2>/dev/null \
        | jq -r 'if (.ips|type)=="object" then (.ips|keys[]) else empty end' 2>/dev/null \
        | sed -e 's/^\[//' -e 's/\]$//' -e '/^$/d' | sort -u
}

_lock_user() {
    local user="$1" limit="$2" ipc="$3" ips="$4" exp card proto
    exec 9>"$JSON_LOCK"
    if ! flock -w 10 9; then
        echo "limit-ip-${TRANSPORT}: ${JSON} busy, will retry"
        exec 9>&-
        return 1
    fi
    exp=$(grep -wE "^### ${user}" "$JSON" 2>/dev/null | cut -d ' ' -f 3 | sort -u | head -n 1)
    if [ -z "$exp" ]; then
        rm -f "$STATE_DIR/$user"
        flock -u 9
        exec 9>&-
        return 0
    fi
    card="$CARD_DIR/${user}.log"
    proto=""
    [ -f "$card" ] && proto=$(grep -E "^(Protokol|Protocol) *:" "$card" 2>/dev/null | awk '{print $NF}')
    proto=${proto^^}
    sed -i "/^### ${user} ${exp}/ {N;d}" "$JSON"
    sed -i -z 's/},\n *\]/}\n        ]/g' "$JSON"
    need_restart=1
    [ -f "$card" ] && mv -f "$card" "$CARD_DIR/${user}.locked"
    mkdir -p "$AUTO_DIR" 2>/dev/null || true
    echo $(( $(date +%s) + 900 )) > "$AUTO_DIR/$user"
    rm -f "$STATE_DIR/$user"
    flock -u 9
    exec 9>&-
    cek="$ipc"
    _ipblock=$(printf '%s\n' "$ips" | sed '/^$/d' | sed 's/.*/<code>&<\/code>/')
    [ -n "$_ipblock" ] || _ipblock="<code>-</code>"
    _ipline="<code>IPs (${ipc}):</code>"
    send_log
    return 0
}

_sample_once() {
    local now user limit state ip iplist ipc eligible over below
    local -A first=()
    local -A newfirst=()
    now=$(date +%s)
    local users
    users=$(grep '^###' "$JSON" 2>/dev/null | cut -d ' ' -f 2 | sort -u)
    for user in $users; do
        limit=$(cat "${LIMIT_DIR}/${user}" 2>/dev/null)
        state="$STATE_DIR/$user"
        if ! [[ "$limit" =~ ^[1-9][0-9]*$ ]]; then
            rm -f "$state"
            continue
        fi
        [ -f "$CARD_DIR/${user}.locked" ] && { rm -f "$state"; continue; }

        iplist=$(_current_ips "$user")
        _state_load "$state"
        over=$_st_over
        below=$_st_below
        # A skipped or overlong run leaves no evidence for the unobserved
        # window.  Do not carry an over-limit timer across that gap.
        if [ "${_st_last:-0}" -gt 0 ] && [ $((now - _st_last)) -gt "$GAP_RESET" ]; then
            over=0
            below=0
        fi
        first=()
        for ip in "${!_st_first[@]}"; do first["$ip"]=${_st_first["$ip"]}; done
        newfirst=()
        for ip in $iplist; do
            if [ -n "${first[$ip]:-}" ]; then
                newfirst["$ip"]=${first["$ip"]}
            else
                newfirst["$ip"]=$now
            fi
        done

        ipc=0
        eligible=""
        for ip in "${!newfirst[@]}"; do
            if [ $((now - newfirst["$ip"])) -ge "$ELIGIBILITY" ]; then
                ipc=$((ipc + 1))
                eligible+="$ip"$'\n'
            fi
        done

        if [ "$ipc" -gt "$limit" ]; then
            [ "$over" -eq 0 ] && over=$now
            below=0
            _st_over=$over
            _st_below=$below
            _st_last=$now
            _st_first=()
            for ip in "${!newfirst[@]}"; do _st_first["$ip"]=${newfirst["$ip"]}; done
            _state_save "$state"
            if [ $((now - over)) -ge "$CONFIRM" ]; then
                _lock_user "$user" "$limit" "$ipc" "$eligible" || true
                continue
            fi
        else
            if [ "$over" -gt 0 ]; then
                [ "$below" -eq 0 ] && below=$now
                if [ $((now - below)) -ge "$RESET_AFTER" ]; then
                    over=0
                    below=0
                fi
            else
                below=0
            fi
            _st_over=$over
            _st_below=$below
            _st_last=$now
            _st_first=()
            for ip in "${!newfirst[@]}"; do _st_first["$ip"]=${newfirst["$ip"]}; done
            _state_save "$state"
        fi
    done
}

_auto_unlock() {
    local _sf _au _due _since _rc
    exec 9>"$JSON_LOCK"
    if ! flock -w 10 9; then
        echo "limit-ip-${TRANSPORT}: ${JSON} busy, auto-unlock skipped"
        exec 9>&-
        return 0
    fi
    for _sf in "$AUTO_DIR"/*; do
        [ -e "$_sf" ] || continue
        _au=$(basename "$_sf")
        if ! [[ "$_au" =~ ^[a-z0-9_]+$ ]]; then
            rm -f "$_sf"
            continue
        fi
        if [ ! -f "$CARD_DIR/${_au}.locked" ]; then
            rm -f "$_sf"
            continue
        fi
        _due=$(cat "$_sf" 2>/dev/null)
        _since=$(stat -c %Y -- "$_sf" 2>/dev/null)
        if ! [[ "$_due" =~ ^[0-9]+$ ]]; then
            if [[ "$_since" =~ ^[0-9]+$ ]]; then
                _due=$(( _since + 900 ))
            else
                _due=$(( $(date +%s) + 900 ))
            fi
        elif [[ "$_since" =~ ^[0-9]+$ ]] && [ "$_due" -lt $(( _since + 800 )) ]; then
            _due=$(( _since + 900 ))
        fi
        if [[ "$_due" =~ ^[0-9]+$ ]] && [ "$(date +%s)" -ge "$_due" ]; then
            XRAY_BATCH=1 "$UNLOCK_BIN" "$_au"
            _rc=$?
            case "$_rc" in
                0) rm -f "$_sf" ;;
                2) rm -f "$_sf"; need_restart=1 ;;
                *) echo "limit-ip-${TRANSPORT}: auto-unlock ${_au} failed (rc=${_rc}); will retry" >&2 ;;
            esac
        fi
    done
    flock -u 9
    exec 9>&-
}

_restart_if_needed() {
    [ "${need_restart:-0}" -eq 1 ] || return 0
    if timeout 30 xray run -test -config "$JSON" >/dev/null 2>&1; then
        timeout 60 systemctl restart "xray@${SERVICE}" >>/dev/null 2>&1 || true
    fi
    need_restart=0
}

_cleanup_state() {
    local users _st _su
    users=$(grep '^###' "$JSON" 2>/dev/null | cut -d ' ' -f 2 | sort -u)
    for _st in "$STATE_DIR"/*; do
        [ -e "$_st" ] || continue
        _su=$(basename "$_st")
        if ! printf '%s\n' "$users" | grep -qxF -- "$_su"; then
            rm -f "$_st"
        fi
    done
}

if ! timeout 10 xray api statsonline --server="127.0.0.1:${STATS_PORT}" -email probe 2>&1 | grep -q "not found"; then
    echo "IP limit check skipped: online statistics unavailable on 127.0.0.1:${STATS_PORT}"
    _auto_unlock
    _restart_if_needed
    exit 0
fi

_start=$(date +%s)
_end=$(( _start + RUN_SECONDS ))
_next=$_start
while :; do
    _sample_once
    _restart_if_needed
    _now=$(date +%s)
    [ "$_now" -ge "$_end" ] && break
    _next=$(( _next + SAMPLE_INTERVAL ))
    [ "$_next" -le "$_now" ] && _next=$(( _now + 1 ))
    sleep $(( _next - _now ))
done

_auto_unlock
_restart_if_needed
_cleanup_state
