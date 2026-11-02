#!/bin/bash
# Found 525: license is enforced only for create/extend/install.
# Found 532: cron has no terminal; suppress output so the root mailbox stays quiet.
if [ ! -t 1 ]; then exec >/dev/null 2>&1; fi

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

clear
echo ""
echo ""
# Bug 72: dropbear on Debian 12 (built without PAM) never checks the shadow
# account-expiry field at login - verified live: an expired account kept
# authenticating until xp's next run (up to 15 minutes) deleted it, because
# the binary contains no expiry check at all. Lock expired accounts here with
# the same passwd -l mechanism the multi-login limiter uses, so logins are
# refused within one cron tick of expiry. extend-ssh unlocks the account again
# when a renewal moves expiry back into the future; xp deletes it for good.

today_days=$(( $(date +%s) / 86400 ))

while IFS=: read -r name _ uid _ _ _ _; do
    # Same enrollment filter as Bug 64: real SSH customers only
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] || continue
    [ "$name" = "nobody" ] && continue
    [ "$name" = "root" ] && continue

    # shadow(5) field 8 = account expiration date (field 7 is inactivity)
    exp_days=$(getent shadow "$name" 2>/dev/null | cut -d: -f8)
    # 0 or empty = never expires; non-numeric = ignore
    [[ "$exp_days" =~ ^[1-9][0-9]*$ ]] || continue

    if [ "$exp_days" -lt "$today_days" ]; then
        # Skip accounts already locked (multi-login limiter, previous run)
        status=$(passwd -S "$name" 2>/dev/null | awk '{print $2}')
        [ "${status#L}" != "$status" ] && continue
        if passwd -l "$name" >/dev/null 2>&1; then
            echo "$name is expired and was locked."
        fi
    fi
done < /etc/passwd

exit 0
