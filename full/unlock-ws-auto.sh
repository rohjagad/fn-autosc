#!/bin/bash
# Auto-unlock for multilogin (IP-limit) locks after 15 minutes.
# Fired by the limit-ip-TIM cron sweeper once the lock age passes
# (~15 min). Manual locks never write sweeper state, so they stay
# indefinite. Silent like the SSH auto-unlock; the manual unlock
# keeps its own Telegram notice.
# XRAY_BATCH=1: caller holds the flock and batches the restart -
# skip both here and exit 2 when a restore happened.
user="$1"
[[ "$user" =~ ^[a-z0-9_]+$ ]] || exit 0
locked="/var/log/create/xray/ws/${user}.locked"
[ -f "$locked" ] || exit 0
uuid=$(grep "UUID" "$locked" | awk '{print $3}')
exp2=$(grep "Expired" "$locked" | awk '{print $3}')
protokol2=$(grep -E "^(Protokol|Protocol) *:" "$locked" | awk '{print $NF}')
protokol2=${protokol2^^}
[ -n "$uuid" ] && [ -n "$exp2" ] && [ -n "$protokol2" ] || { echo "unlock-ws-auto: invalid locked card for $user; lock kept" >&2; exit 1; }
# Already active: never append a second copy.  If a previous
# partial unlock left the card as .locked, put the card back so the
# caller can drop the due state without leaving a locked card.
if grep -qxF "### $user $exp2" /etc/xray/json/ws.json 2>/dev/null; then
    if [ -f "/var/log/create/xray/ws/${user}.log" ]; then
        rm -f "$locked" || { echo "unlock-ws-auto: failed to remove locked card for $user; lock kept" >&2; exit 1; }
    else
        mv "$locked" "/var/log/create/xray/ws/${user}.log" || { echo "unlock-ws-auto: failed to move locked card for $user; lock kept" >&2; exit 1; }
    fi
    exit 0
fi
if [ -z "$XRAY_BATCH" ]; then
    exec 9>/tmp/xray-json-ws.lock
    flock -w 30 9 || exit 0
fi
if [ "$protokol2" == "VMESS" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/ws.json vmess "$user" "$exp2" "$uuid" || { echo "unlock-ws-auto: failed to insert $user into the JSON config." >&2; exit 1; }
elif [ "$protokol2" == "VLESS" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/ws.json vless "$user" "$exp2" "$uuid" || { echo "unlock-ws-auto: failed to insert $user into the JSON config." >&2; exit 1; }
elif [ "$protokol2" == "TROJAN" ]; then
# Found 539: insert through the shared helper; no template anchor object.
xray-add-client /etc/xray/json/ws.json trojan "$user" "$exp2" "$uuid" || { echo "unlock-ws-auto: failed to insert $user into the JSON config." >&2; exit 1; }
else
    echo "unlock-ws-auto: unknown protocol for $user; lock kept" >&2
    exit 1
fi
# Found 497 guard: the re-add above can fail when the JSON clients array
# is missing from the config. Moving .locked
# to .log without a JSON entry hands the account to auto-delete-*, which
# wipes card + quota + limit files ("Log Cleanup") - a locked account would
# be silently DELETED instead of unlocked. Verify the entry landed; if not,
# keep the lock and fail LOUD so the operator repairs the JSON config first.
if ! grep -qxF "### $user $exp2" /etc/xray/json/ws.json 2>/dev/null; then
    echo "unlock-ws-auto: FAILED to restore $user - JSON client insertion failed, lock kept. Check the JSON config, then unlock manually." >&2
    exit 1
fi
# Multilogin auto-unlock notice (timer-expired locks only; the manual
# unlock keeps its own message). Sent after the restore is verified below.
send_unlocked() {
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)
KEY=$(cat /etc/funny/.keybot 2>/dev/null)
[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0
URL="https://api.telegram.org/bot$KEY/sendMessage"
TIME="10"
DATE=$(date +"%d-%b-%Y %H:%M:%S")
TEXT="
<b>-----------------------</b>
<b>MULTILOGIN UNLOCKED</b>
<b>-----------------------</b>
<code>Date     : $DATE</code>
<code>Username : $user</code>
<code>Protocol : $protokol2</code>
<code>Transport: WS</code>
<code>Status   : Unlocked</code>
<b>-----------------------</b>
<i>Catatan:</i> The lock period ended and the account can be used again."
curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&parse_mode=html" --data-urlencode "text=$TEXT" $URL >/dev/null
}
if xray run -test -config /etc/xray/json/ws.json >/dev/null 2>&1; then
    mv "$locked" "/var/log/create/xray/ws/${user}.log" || { echo "unlock-ws-auto: failed to move locked card for $user; lock kept" >&2; exit 1; }
    send_unlocked
    [ -n "$XRAY_BATCH" ] && exit 2
    systemctl daemon-reload
    systemctl restart xray@ws
else
    echo "unlock-ws-auto: config test failed for $user; lock kept" >&2
    exit 1
fi
