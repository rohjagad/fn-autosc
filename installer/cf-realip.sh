#!/bin/bash
# Refresh the Cloudflare ranges used by set_real_ip_from in /etc/nginx/nginx.conf.
#
# nginx trusts Cloudflare's CF-Connecting-IP header only for peers inside
# set_real_ip_from, so a range Cloudflare publishes after an install would not be
# trusted: requests from that edge would keep the edge as $remote_addr and the IP
# limit would count Cloudflare edges instead of clients, locking accounts. Run
# this after Cloudflare changes its list; installer/diamond.sh also schedules it
# weekly. Everything is best-effort - if the fetch, the rewrite or `nginx -t`
# fails, the current configuration is left exactly as it was.
set -o pipefail

CONF=/etc/nginx/nginx.conf
[ -f "$CONF" ] || exit 0
grep -q 'set_real_ip_from' "$CONF" || exit 0

cf4=$(curl -4 -fsS --max-time 15 https://www.cloudflare.com/ips-v4 2>/dev/null)
cf6=$(curl -4 -fsS --max-time 15 https://www.cloudflare.com/ips-v6 2>/dev/null)

# Both lists must be non-empty and every line must look like a CIDR.
for list in "$cf4" "$cf6"; do
    [ -n "$list" ] || exit 0
    printf '%s\n' "$list" | grep -qvE '^[0-9a-fA-F:.]+/[0-9]{1,3}$' && exit 0
done

tmp=$(mktemp) || exit 0
trap 'rm -f "$tmp"' EXIT

awk -v v4="$cf4" -v v6="$cf6" '
    /^[[:space:]]*set_real_ip_from / { next }
    /^[[:space:]]*real_ip_header CF-Connecting-IP;/ && !done {
        n = split(v4, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") print "    set_real_ip_from " a[i] ";"
        n = split(v6, b, "\n"); for (i = 1; i <= n; i++) if (b[i] != "") print "    set_real_ip_from " b[i] ";"
        done = 1
    }
    { print }
' "$CONF" > "$tmp"

grep -q 'set_real_ip_from' "$tmp" || exit 0
diff -q "$CONF" "$tmp" >/dev/null 2>&1 && exit 0

cp -a "$CONF" "$CONF.cf-realip.bak"
cp "$tmp" "$CONF"
if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx >/dev/null 2>&1
    rm -f "$CONF.cf-realip.bak"
else
    cp -a "$CONF.cf-realip.bak" "$CONF"
    rm -f "$CONF.cf-realip.bak"
fi
exit 0
