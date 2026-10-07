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
locked="/var/log/create/xray/http/${user}.locked"
[ -f "$locked" ] || exit 0
uuid=$(grep "UUID" "$locked" | awk '{print $3}')
exp2=$(grep "Expired" "$locked" | awk '{print $3}')
protokol2=$(grep "Protokol:" "$locked" | awk '{print $2}')
[ -n "$uuid" ] && [ -n "$exp2" ] && [ -n "$protokol2" ] || exit 0
# Already active: never append a second copy, and unlike the manual
# unlock do not touch files either - just leave quietly.
grep -qxF "### $user $exp2" /etc/xray/json/upgrade.json 2>/dev/null && exit 0
if [ -z "$XRAY_BATCH" ]; then
    exec 9>/tmp/xray-json-upgrade.lock
    flock -w 30 9 || exit 0
fi
if [ "$protokol2" == "Vmess" ]; then
    sed -i '/#vmess$/{n;s/}/},\n### '"$user $exp2"'\n{"id": "'""$uuid""'","alterid": 0,"email": "'""$user""'","level": 0}/}' /etc/xray/json/upgrade.json
elif [ "$protokol2" == "Vless" ]; then
    sed -i '/#vless$/{n;s/}/},\n### '"$user $exp2"'\n{"id": "'""$uuid""'","email": "'""$user""'","level": 0}/}' /etc/xray/json/upgrade.json
elif [ "$protokol2" == "Trojan" ]; then
    sed -i '/#trojan$/{n;s/}/},\n### '"$user $exp2"'\n{"password": "'""$uuid""'","email": "'""$user""'","level": 0}/}' /etc/xray/json/upgrade.json
else
    exit 0
fi
if xray run -test -config /etc/xray/json/upgrade.json >/dev/null 2>&1; then
    mv "$locked" "/var/log/create/xray/http/${user}.log"
    [ -n "$XRAY_BATCH" ] && exit 2
    systemctl daemon-reload
    systemctl restart xray@upgrade
fi
