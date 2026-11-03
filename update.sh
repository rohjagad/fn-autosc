#!/bin/bash
#
# FN AutoSC updater: live marker -> 5f378ba
#
# Applies the commits on top of b6d1a97 (1-minute evidence window,
# Exp-Date-N/A binary fix, LOCKED IPs block, MULTILOGIN UNLOCKED
# notices, working SSH banner wiring + default, xp lock-in-flight +
# empty-expiry guard, IP evidence map + CGNAT stable-set gate, Xray
# auto-unlock at least 15 minutes, restore version-marker/formatter
# guard, SSH active-IP limit/display with real WS/CDN client IPs,
# per-file payload instead of the menu zip, payload web restore-ftp,
# 777 HAProxy mapping with section-scoped logging checks, retry-safe
# auto-unlock, slow-auth/IPv6 counts, scoped SSH expiry without a
# global daemon restart, installer-domain/rotated-domain separation
# with per-domain account counts, licence gate scoped to create/extend/
# install so maintenance and quota daemons no longer depend on auth, backup
# Telegram IP always populated with probe fallbacks and strict IPv4 validation,
# main-menu licence identity restored without gating under a LICENSE heading,
# account cards showing only the rotated domain, xHTTP access-log bounding,
# cron output suppression when stdout is not a terminal, quota startup output
# guarded for systemd, legacy dnstt/nsdomain synchronization, simpang32 quota
# repair, published default-credential neutralization, root-mail archiving,
# stale SSH-limit cleanup, removal of the template client anchors,
# panel-account-only SSH IP limiting, complete domain-deletion cleanup
# with balanced card reassignment, and NULL-query support for HTTP Custom's
# SlowDNS client)
# to a live install. The file set is a superset covering the earlier
# ranges too, so older installs are brought fully up to date in one
# run. Safe to run: files are backed up first, every download is
# verified before it replaces anything, and cron/menu scripts need no
# restart (only ssh/dropbear restart, and only if banner wiring was
# missing).
#
# Usage:
#   bash update.sh                  # live marker -> 5f378ba (default)
#   bash update.sh <commit> --force  # re-apply even if already recorded
#
# One-line remote run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)

set -u

# Fallback baseline: the live v1.23 install (Found 520).  The real starting
# version is read from the live panel below, so this value only appears when
# both markers are missing.
FROM="6b967af9e0ebadc76a265132e49d62a27ad72235"
TARGET="${1:-5f378ba4e1b66a71cdafe658be3b35dbad86e1a7}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

# Found 520: do not assume the live panel is at the historical 5c48741
# baseline.  The last applied update is the current live version; a box that
# was never updated falls back to its install commit.
_live_from=""
for _marker in /etc/funny/.update-commit /etc/funny/.install-commit; do
    [ -s "$_marker" ] || continue
    _candidate=$(tr -d '[:space:]' < "$_marker" 2>/dev/null)
    case "$_candidate" in
        "" | Unknown) continue ;;
        *) _live_from="$_candidate"; break ;;
    esac
done
[ -n "$_live_from" ] && FROM="$_live_from"

# Downloader (same bootstrap the README install command uses).
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
    apt-get update -qq && apt-get install -y curl
}
fetch() {
    # $1=url $2=dest $3=timeout seconds (default 600; VPS links to GitHub
    # are sometimes slow, and Found 518 applies the same bound to scripts).
    local _timeout="${3:-600}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time "$_timeout" --retry 2 --retry-delay 5 "$1" -o "$2"
    else
        wget -q --timeout="$_timeout" --tries=3 -O "$2" "$1"
    fi
}

# Skip when this exact target is already recorded (unless --force).
if [ "$FORCE" -eq 0 ] && [ -f /etc/funny/.update-commit ] && \
    [ "$(cat /etc/funny/.update-commit 2>/dev/null)" = "$TARGET" ]; then
    echo "Already at $TARGET (/etc/funny/.update-commit). Nothing to do."
    echo "Use 'bash update.sh $TARGET --force' to re-apply."
    exit 0
fi

# Edition: full ships SSH/NoobzVPN/L2TP menus, lite does not.
if [ -e /usr/bin/addssh ] || [ -e /usr/bin/xl2tp ] || [ -e /usr/bin/menu-noobz ]; then
    EDITION="full"
else
    EDITION="lite"
fi
echo "Edition detected: $EDITION"
echo "Live version: ${FROM:0:7} -> ${TARGET:0:7}"

# Found 512: the SSH IP limiter/menu use the ssh-online helper (stdlib Python)
# to resolve WS/CDN clients to their real IPs.
if [ "$EDITION" = "full" ] && ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for ssh-online (SSH IP limit). Install python3 first." >&2
    exit 1
fi

# Deployed name (no .sh) -> repo source name.
FILES="xp quota-xhttp kill-xhttp limit-ip-ws limit-ip-http limit-ip-xhttp limit-ip-grpc
delete-ws delete-xhttp menu-system menu backup bmenu dm-menu
add-trojan-grpc add-trojan-http add-trojan-ws add-trojan-xhttp add-vless-grpc add-vless-http add-vless-ws add-vless-xhttp add-vmess-grpc add-vmess-http add-vmess-ws add-vmess-xhttp trial-trojan-grpc trial-trojan-http trial-trojan-ws trial-trojan-xhttp trial-vless-grpc trial-vless-http trial-vless-ws trial-vless-xhttp trial-vmess-grpc trial-vmess-http trial-vmess-ws trial-vmess-xhttp
unlock-ws-auto unlock-http-auto unlock-xhttp-auto unlock-grpc-auto
auto-delete-grpc auto-delete-http auto-delete-ws auto-delete-xhttp
change-id-grpc change-id-http change-id-ws change-id-xhttp
change-quota-grpc change-quota-http change-quota-ws change-quota-xhttp
delete-grpc delete-http
extend-grpc extend-http extend-ws extend-xhttp
kill-grpc kill-http kill-ws
list-xray-grpc list-xray-http list-xray-ws list-xray-xhttp
locked-xray-grpc locked-xray-http locked-xray-ws locked-xray-xhttp
menu-argo menu-bot
quota-grpc quota-http quota-ws
routing-grpc routing-http routing-ws routing-xhttp
unlock-grpc unlock-http unlock-ws unlock-xhttp
x-grpc x-http x-ws x-xhttp xray-add-client"
# format.sh lives in config/ and installs to /etc/funny, not /usr/bin.
CONFIG_FILES="format.sh"
# Found 514: /usr/bin/restore-ftp is the non-interactive website variant
# installed by website/install.sh (it reads /var/www/uploads/*.zip).  The
# full/lite restore-ftp.sh files carry interactive TUI prompts and must not
# overwrite it on a live box.
WEB_FILES="restore-ftp"
if [ "$EDITION" = "full" ]; then
    FILES="$FILES addssh trial-ssh menu-wg xl2tp menu-noobz limit-ip-ssh cek-login-ssh ssh-online menu-ssh expire-ssh menu-dnstt menu-x"
else
    # Lite only: this viewer used to truncate ws.log at the end (Found 508).
    FILES="$FILES cek-xray-ws"
fi

# Expected marker per file: proves the download is the fixed version.
marker_for() {
    case "$1" in
        xp) echo 'Found 532' ;;
        expire-ssh) echo 'Found 532' ;;
        quota-xhttp | quota-ws | quota-http | quota-grpc) echo 'Found 533' ;;
        xray-add-client) echo 'Found 539' ;;
        kill-xhttp) echo 'Found 531' ;;
        limit-ip-ssh) echo 'Found 540' ;;
        cek-login-ssh) echo 'WS/HAProxy mapping unavailable' ;;
        ssh-online) echo 'HAPROXY_TOL_US' ;;
        menu-ssh) echo 'haproxy -v' ;;
        cek-xray-ws) echo 'Found 508: keep the access log' ;;
        backup) echo 'Found 529' ;;
        restore-ftp | bmenu) echo 'Found 511' ;;
        format.sh) echo 'Press any key to return...' ;;
        limit-ip-*) echo 'Found 532' ;;
        auto-delete-*) echo 'Found 532' ;;
        kill-ws | kill-http | kill-grpc) echo 'Found 532' ;;
        unlock-*-auto) echo 'invalid locked card for $user' ;;
        delete-ws) echo 'Delete WS Account' ;;
        delete-xhttp) echo 'Delete XHTTP Account' ;;
        menu-system) echo 'Banner /etc/issue.net' ;;
        menu) echo 'Found 528' ;;
        dm-menu) echo 'Found 542' ;;
        menu-wg | xl2tp | menu-noobz) echo 'Rotated Domain' ;;
        add-* | trial-*) echo 'Rotated Domain' ;;
        addssh | trial-ssh) echo 'Rotated Domain' ;;
        *) echo 'Found 525' ;;
    esac
}

BACKUP="/root/fn-update-backup-$(date +%Y%m%d-%H%M%S)"
STAGE=$(mktemp -d) || { echo "Cannot create staging dir."; exit 1; }
BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/${EDITION}"
CONFIG_BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/config"
WEB_BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/website"
BIN_BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/bin/${EDITION}"

# change-limit-ip tools ship as standalone compiled binaries (no .sh to
# syntax-check), so they travel separately with pinned md5 fingerprints per
# edition instead of text markers. Found 513: no menu zip anymore.
BINARIES="change-limit-ip-ws change-limit-ip-http change-limit-ip-xhttp change-limit-ip-grpc"
if [ "$EDITION" = "full" ]; then
    BINARIES="$BINARIES limit-ip"
fi
bin_md5() {
    if [ "$EDITION" = "full" ]; then
        case "$1" in
            change-limit-ip-ws) echo '98f5d2f80b41a8ad348514638c0120be' ;;
            change-limit-ip-http) echo 'fd1a02d7e522c9e7d89b1bee07e0a5e8' ;;
            change-limit-ip-xhttp) echo '3bf12a8521c3577abb3400400effeff3' ;;
            change-limit-ip-grpc) echo '5ed18b1ac5a98ef47531cd01474b08ed' ;;
            limit-ip) echo '5ec7165a8c912c0b00184b1f1ea73c8e' ;;
        esac
    else
        case "$1" in
            change-limit-ip-ws) echo 'a4b054fae469ab64422a3909a59488ff' ;;
            change-limit-ip-http) echo 'd4e7995e106878381bd3a0b6df95418a' ;;
            change-limit-ip-xhttp) echo 'b27c49c60f092e664a9d786eaaeaf2ab' ;;
            change-limit-ip-grpc) echo 'cefb9eb84c13b252ea0e21524e8ec9bb' ;;
        esac
    fi
}

# Found 521/522: the domain files were renamed and the installer domain is no
# longer implicit in the rotation. Copy legacy files to the new names before
# new scripts are installed, keep the legacy names until the install succeeds,
# and seed the installer domain once when the rotated list is first created.
seed_installer_rotated_domain() {
    local inst="/etc/xray/installer-domain" rot="/etc/xray/rotated-domains" d
    [ -s "$inst" ] || return 0
    d=$(tr -d '[:space:]' < "$inst")
    [ -n "$d" ] || return 0
    mkdir -p /etc/xray || return 1
    if ! grep -qxF "$d" "$rot" 2>/dev/null; then
        {
            printf '%s\n' "$d"
            if [ -s "$rot" ]; then
                awk 'NF' "$rot"
            fi
        } > "$rot.tmp" || return 1
        mv -f "$rot.tmp" "$rot" || return 1
    fi
    return 0
}

migrate_domain_layout() {
    local old new base seed_rotated=0
    mkdir -p "$BACKUP/domain-files" || return 1
    for pair in \
        "/etc/xray/domain:/etc/xray/installer-domain" \
        "/etc/xray/domains:/etc/xray/rotated-domains" \
        "/etc/xray/.domainseq:/etc/xray/.rotated-domainseq"; do
        old=${pair%%:*}
        new=${pair##*:}
        [ -f "$old" ] || continue
        base=$(basename "$old")
        cp -a "$old" "$BACKUP/domain-files/$base" || return 1
        if [ ! -f "$new" ]; then
            cp -a "$old" "$new" || return 1
            [ "$new" = "/etc/xray/rotated-domains" ] && seed_rotated=1
        fi
    done
    if [ "$seed_rotated" -eq 1 ] || [ ! -e /etc/xray/rotated-domains ]; then
        seed_installer_rotated_domain || return 1
    fi
    return 0
}

remove_legacy_domain_files() {
    [ -f /etc/xray/installer-domain ] && rm -f /etc/xray/domain
    [ -f /etc/xray/rotated-domains ] && rm -f /etc/xray/domains
    [ -f /etc/xray/.rotated-domainseq ] && rm -f /etc/xray/.domainseq
    return 0
}

# Phase 1: download everything, syntax-check + marker-check everything.
echo "Downloading ${TARGET} (${EDITION})..."
for name in $FILES; do
    fetch "${BASE}/${name}.sh" "${STAGE}/${name}" || {
        echo "FAILED to download ${name}.sh - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    [ -s "${STAGE}/${name}" ] || {
        echo "Downloaded ${name}.sh is empty - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    bash -n "${STAGE}/${name}" || {
        echo "${name}.sh failed syntax check - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    grep -qF "$(marker_for "$name")" "${STAGE}/${name}" || {
        echo "${name}.sh lacks its fix marker - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    echo "  ok: $name"
done

# Phase 1a: config files installed outside /usr/bin (currently format.sh).
for name in $CONFIG_FILES; do
    fetch "${CONFIG_BASE}/${name}" "${STAGE}/${name}" || {
        echo "FAILED to download config/${name} - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    [ -s "${STAGE}/${name}" ] || {
        echo "Downloaded config/${name} is empty - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    bash -n "${STAGE}/${name}" || {
        echo "config/${name} failed syntax check - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    grep -qF "$(marker_for "$name")" "${STAGE}/${name}" || {
        echo "config/${name} lacks its fix marker - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    echo "  ok: $name"
done

# Phase 1b: standalone binaries (md5 verified individually).
echo "Downloading ${EDITION} binaries..."
for b in $BINARIES; do
    fetch "${BIN_BASE}/${b}" "${STAGE}/${b}" 600 || {
        echo "FAILED to download $b - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    [ -s "${STAGE}/${b}" ] || {
        echo "Downloaded $b is empty - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    [ "$(md5sum < "${STAGE}/${b}" | cut -d' ' -f1)" = "$(bin_md5 "$b")" ] || {
        echo "$b fingerprint mismatch - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    echo "  ok: $b"
done

# Phase 1c: website files installed into /usr/bin (currently restore-ftp).
for name in $WEB_FILES; do
    fetch "${WEB_BASE}/${name}.sh" "${STAGE}/web-${name}" || {
        echo "FAILED to download website/${name}.sh - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    [ -s "${STAGE}/web-${name}" ] || {
        echo "Downloaded website/${name}.sh is empty - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    bash -n "${STAGE}/web-${name}" || {
        echo "website/${name}.sh failed syntax check - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    grep -qF "$(marker_for "$name")" "${STAGE}/web-${name}" || {
        echo "website/${name}.sh lacks its fix marker - aborting, nothing changed."
        rm -rf "$STAGE"
        exit 1
    }
    echo "  ok: website/${name}.sh"
done

# Phase 2: back up current files, then install.
if ! migrate_domain_layout; then
    echo "Domain file migration failed - aborting, nothing installed."
    rm -rf "$STAGE"
    exit 1
fi
mkdir -p "$BACKUP"
for name in $FILES; do
    [ -e "/usr/bin/${name}" ] && cp -f "/usr/bin/${name}" "${BACKUP}/${name}"
    install -m 0755 "${STAGE}/${name}" "/usr/bin/${name}"
done
for b in $BINARIES; do
    [ -e "/usr/bin/${b}" ] && cp -f "/usr/bin/${b}" "${BACKUP}/${b}"
    install -m 0755 "${STAGE}/${b}" "/usr/bin/${b}"
done
for name in $WEB_FILES; do
    [ -e "/usr/bin/${name}" ] && cp -f "/usr/bin/${name}" "${BACKUP}/${name}"
    install -m 0755 "${STAGE}/web-${name}" "/usr/bin/${name}"
done
mkdir -p /etc/funny
for name in $CONFIG_FILES; do
    [ -e "/etc/funny/${name}" ] && cp -f "/etc/funny/${name}" "${BACKUP}/funny-${name}"
    install -m 0755 "${STAGE}/${name}" "/etc/funny/${name}"
done
rm -rf "$STAGE"
remove_legacy_domain_files || true

# ---------------------------------------------------------------------------
# Fix 533-543: one-time live-state migrations.
#
# The payload only contains scripts.  The state below lives outside the
# repository (systemd units, quota files, JSON configs, mailboxes, SSH limit
# files), so it has to be migrated once on each existing box.  Every function
# is best-effort: a missing optional file or a failed parse must never roll
# back an otherwise successful payload install.
# ---------------------------------------------------------------------------
fix_marker() {
    mkdir -p /etc/funny 2>/dev/null || true
    : > "/etc/funny/$1" 2>/dev/null || true
    chmod 600 "/etc/funny/$1" 2>/dev/null || true
}

fix_log() {
    echo "$(date '+%F %T') $*" >> /etc/xray/.quota.logs 2>/dev/null || true
}

# Found 533: the quota daemons are long-running.  Installing a new script is
# not enough; the old process keeps the old file in memory until it restarts.
restart_quota_services() {
    local svc
    for svc in quota-ws quota-http quota-grpc quota-xhttp; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl restart "$svc" 2>/dev/null || true
        fi
    done
    echo "Quota services restarted with the Fix 533 startup guard."
}

# Found 534: older installs wrote dnstt.service with a nameserver that no
# longer matches /etc/slowdns/nsdomain.  The unit is the value the server
# actually uses; make it follow the saved file.
sync_dnstt_unit() {
    local marker="/etc/funny/.fix534-dnstt-synced"
    local unit="/etc/systemd/system/dnstt.service"
    local nsfile="/etc/slowdns/nsdomain"
    local nsd="" cur="" newcur="" backup=""
    [ -f "$marker" ] && return 0
    [ -f "$unit" ] || return 0
    [ -s "$nsfile" ] || return 0
    nsd=$(tr -d '[:space:]' < "$nsfile" 2>/dev/null)
    [ -n "$nsd" ] || return 0
    if ! [[ "$nsd" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]]; then
        echo "Fix 534: /etc/slowdns/nsdomain is not a valid hostname; dnstt unit left unchanged." >&2
        return 0
    fi
    cur=$(sed -nE 's/.*-privkey-file[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*/\1/p' "$unit" 2>/dev/null | head -n 1)
    if [ "$cur" = "$nsd" ]; then
        fix_marker .fix534-dnstt-synced
        return 0
    fi
    mkdir -p "$BACKUP" 2>/dev/null || true
    backup="/root/fn-dnstt-backup-$(date +%Y%m%d-%H%M%S).service"
    cp -f "$unit" "$BACKUP/dnstt.service" 2>/dev/null || true
    cp -f "$unit" "$backup" 2>/dev/null || true
    sed -i -E "s|^([[:space:]]*ExecStart=.*-privkey-file[[:space:]]+[^[:space:]]+[[:space:]]+)[^[:space:]]+|\\1${nsd}|" "$unit" 2>/dev/null || {
        echo "Fix 534: could not rewrite dnstt.service; unit left unchanged." >&2
        return 0
    }
    newcur=$(sed -nE 's/.*-privkey-file[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*/\1/p' "$unit" 2>/dev/null | head -n 1)
    if [ "$newcur" != "$nsd" ]; then
        cp -f "$BACKUP/dnstt.service" "$unit" 2>/dev/null || true
        echo "Fix 534: dnstt.service rewrite did not verify; original restored." >&2
        return 0
    fi
    systemctl daemon-reload 2>/dev/null || true
    if systemctl is-active --quiet dnstt 2>/dev/null; then
        systemctl restart dnstt 2>/dev/null || true
    fi
    fix_log "fix534: dnstt nameserver ${cur:-unknown} -> ${nsd}"
    fix_marker .fix534-dnstt-synced
    echo "Fix 534: dnstt nameserver synchronized to ${nsd}."
}

# Found 543: dnstt only answers QTYPE TXT.  HTTP Custom's SlowDNS client sends
# QTYPE NULL when its Type setting is NULL, so the server returned NXDOMAIN and
# the app reported SocketException before SSH authentication.  Rebuild the
# installed server from the pinned dnstt source with NULL-query support.
install_dnstt_null_support() {
    local marker="/etc/funny/.fix543-dnstt-null"
    local bin="/etc/slowdns/dns-server"
    local unit="/etc/systemd/system/dnstt.service"
    local nsfile="/etc/slowdns/nsdomain"
    local nsd="" src="" out="" probe=""
    [ -f "$marker" ] && return 0
    [ -x "$bin" ] || return 0
    [ -f "$unit" ] || return 0
    [ -s "$nsfile" ] || return 0
    systemctl is-active --quiet dnstt 2>/dev/null || return 0
    nsd=$(tr -d '[:space:]' < "$nsfile" 2>/dev/null)
    [ -n "$nsd" ] || return 0
    probe="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.${nsd}"
    if [ -x /usr/local/go/bin/go ]; then
        PATH="/usr/local/go/bin:$PATH"
        export PATH
    fi
    command -v go >/dev/null 2>&1 || {
        echo "Fix 543: Go is missing; dnstt left unchanged." >&2
        return 0
    }
    command -v git >/dev/null 2>&1 || {
        echo "Fix 543: git is missing; dnstt left unchanged." >&2
        return 0
    }

    # A box installed after this fix already has the patched binary; its
    # installer writes the marker.  This probe also catches a manual rebuild.
    if command -v dig >/dev/null 2>&1; then
        out=$(dig @127.0.0.1 -p 5300 -t TYPE10 +time=2 +tries=1 "$probe" 2>/dev/null || true)
        if printf '%s\n' "$out" | grep -q "status: NOERROR"; then
            fix_marker .fix543-dnstt-null
            echo "Fix 543: dnstt already accepts NULL queries."
            return 0
        fi
    fi

    src=$(mktemp -d) || return 0
    if ! fetch "https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/installer/dnstt-null.patch" "$src/dnstt-null.patch" 120; then
        rm -rf "$src"
        echo "Fix 543: could not download the dnstt NULL patch; dnstt left unchanged." >&2
        return 0
    fi
    if ! git clone -q https://github.com/rohjagad/dnstt.git "$src/dnstt" >/dev/null 2>&1; then
        rm -rf "$src"
        echo "Fix 543: could not clone dnstt; dnstt left unchanged." >&2
        return 0
    fi
    if ! git -C "$src/dnstt" checkout -q 17aa1fed864cd5493e3d09a14df1b8b5cc1df123 >/dev/null 2>&1; then
        rm -rf "$src"
        echo "Fix 543: could not check out the pinned dnstt source; dnstt left unchanged." >&2
        return 0
    fi
    if ! git -C "$src/dnstt" apply "$src/dnstt-null.patch" >/dev/null 2>&1; then
        rm -rf "$src"
        echo "Fix 543: dnstt NULL patch did not apply; dnstt left unchanged." >&2
        return 0
    fi
    if ! ( cd "$src/dnstt/dnstt-server" && go build -o "$src/dns-server" . ) >"$src/build.log" 2>&1; then
        echo "Fix 543: dnstt build failed; dnstt left unchanged." >&2
        tail -n 5 "$src/build.log" >&2 2>/dev/null || true
        rm -rf "$src"
        return 0
    fi
    if [ ! -x "$src/dns-server" ]; then
        rm -rf "$src"
        echo "Fix 543: dnstt build produced no binary; dnstt left unchanged." >&2
        return 0
    fi
    mkdir -p "$BACKUP" 2>/dev/null || true
    if ! cp -f "$bin" "$BACKUP/dns-server" 2>/dev/null; then
        rm -rf "$src"
        echo "Fix 543: could not back up the current dnstt binary; dnstt left unchanged." >&2
        return 0
    fi
    if ! install -m 0755 "$src/dns-server" "$bin" 2>/dev/null; then
        cp -f "$BACKUP/dns-server" "$bin" 2>/dev/null || true
        rm -rf "$src"
        echo "Fix 543: could not install the rebuilt dnstt binary; previous binary restored." >&2
        return 0
    fi
    systemctl restart dnstt >/dev/null 2>&1 || true
    sleep 1
    if ! systemctl is-active --quiet dnstt 2>/dev/null; then
        cp -f "$BACKUP/dns-server" "$bin" 2>/dev/null || true
        systemctl restart dnstt >/dev/null 2>&1 || true
        rm -rf "$src"
        echo "Fix 543: rebuilt dnstt did not start; previous binary restored." >&2
        return 0
    fi
    if command -v dig >/dev/null 2>&1; then
        out=$(dig @127.0.0.1 -p 5300 -t TYPE10 +time=3 +tries=1 "$probe" 2>/dev/null || true)
        if ! printf '%s\n' "$out" | grep -q "status: NOERROR"; then
            cp -f "$BACKUP/dns-server" "$bin" 2>/dev/null || true
            systemctl restart dnstt >/dev/null 2>&1 || true
            rm -rf "$src"
            echo "Fix 543: rebuilt dnstt did not answer NULL; previous binary restored." >&2
            return 0
        fi
    fi
    rm -rf "$src"
    fix_log "fix543: dnstt rebuilt with NULL QTYPE support"
    fix_marker .fix543-dnstt-null
    echo "Fix 543: dnstt rebuilt with NULL QTYPE support."
}

# Found 535: a legacy account lost its base quota and IP-limit files while the
# usage counter and the card survived.  Restore only when both files are
# absent and the card still describes 100 GB / IP 2.
repair_simpang32() {
    local marker="/etc/funny/.fix535-simpang32"
    local card="/var/log/create/xray/ws/simpang32.log"
    local q="/etc/xray/quota/ws/simpang32"
    local l="/etc/xray/limit/ip/xray/ws/simpang32"
    local usage="/etc/xray/quota/ws/simpang32_usage"
    local qgb="" ip="" qbytes=""
    [ -f "$marker" ] && return 0
    [ -f "$card" ] || return 0
    [ -f /etc/xray/json/ws.json ] || return 0
    grep -q '^### simpang32 ' /etc/xray/json/ws.json 2>/dev/null || return 0
    if [ -e "$q" ] || [ -e "$l" ]; then
        echo "Fix 535: simpang32 already has quota/IP-limit state; leaving it unchanged."
        fix_marker .fix535-simpang32
        return 0
    fi
    qgb=$(sed -nE 's/^[[:space:]]*Quota[[:space:]]*:[[:space:]]*([0-9]+)[[:space:]]*GB[[:space:]]*$/\1/p' "$card" 2>/dev/null | tail -n 1)
    ip=$(sed -nE 's/^[[:space:]]*Limit IP[[:space:]]*:[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' "$card" 2>/dev/null | tail -n 1)
    if ! [[ "$qgb" =~ ^[1-9][0-9]*$ ]] || ! [[ "$ip" =~ ^[1-9][0-9]*$ ]]; then
        echo "Fix 535: could not parse simpang32 card; quota/IP limit left unchanged." >&2
        return 0
    fi
    qbytes=$((qgb * 1073741824))
    mkdir -p "$(dirname "$q")" "$(dirname "$l")" 2>/dev/null || return 0
    mkdir -p "$BACKUP" 2>/dev/null || true
    cp -f "$card" "$BACKUP/simpang32-card.log" 2>/dev/null || true
    [ -f "$usage" ] && cp -f "$usage" "$BACKUP/simpang32_usage" 2>/dev/null || true
    if ! printf '%s\n' "$qbytes" > "$q" 2>/dev/null; then
        echo "Fix 535: could not write simpang32 quota file." >&2
        return 0
    fi
    if ! printf '%s\n' "$ip" > "$l" 2>/dev/null; then
        rm -f "$q" 2>/dev/null || true
        echo "Fix 535: could not write simpang32 IP-limit file." >&2
        return 0
    fi
    chmod 644 "$q" "$l" 2>/dev/null || true
    fix_log "fix535: restored simpang32 quota=${qbytes} limit=${ip}"
    fix_marker .fix535-simpang32
    echo "Fix 535: restored simpang32 quota ${qgb} GB / IP ${ip}."
}

# Found 536: the public templates shipped known default UUID/password values.
# The installer already randomizes them on a fresh install; this one-time
# migration protects boxes installed before that code.  The default client
# objects stay in place because the add/trial scripts use them as anchors.
neutralize_default_credentials() {
    local marker="/etc/funny/.fix536-default-creds"
    local dir="/etc/xray/json"
    local files="$dir/ws.json $dir/upgrade.json $dir/xhttp.json $dir/grpc.json"
    local defs="rerechan-store cfbbaafc-8d52-450c-9fb0-145bc8221e6d 019e0bf3-dd56-11e9-aa37-5600024c1d6a af7d5cf8-442d-4bb3-8a76-eb367178781d diy2020 nonescript-fn-project"
    local f def rep svc found=0
    [ -f "$marker" ] && return 0
    command -v xray >/dev/null 2>&1 || return 0
    for f in $files; do
        [ -f "$f" ] || return 0
    done
    for def in $defs; do
        if grep -qF "$def" $files 2>/dev/null; then
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        fix_marker .fix536-default-creds
        echo "Fix 536: published default credentials already absent."
        return 0
    fi
    mkdir -p "$BACKUP/json" 2>/dev/null || return 0
    for f in $files; do
        cp -f "$f" "$BACKUP/json/$(basename "$f")" 2>/dev/null || true
    done
    for def in $defs; do
        grep -qF "$def" $files 2>/dev/null || continue
        rep=$(xray uuid 2>/dev/null) || continue
        [ -n "$rep" ] || continue
        sed -i "s|${def}|${rep}|g" $files 2>/dev/null || true
    done
    for f in $files; do
        if ! xray run -test -config "$f" >/dev/null 2>&1; then
            for def in $files; do
                cp -f "$BACKUP/json/$(basename "$def")" "$def" 2>/dev/null || true
            done
            echo "Fix 536: Xray rejected $f after credential replacement; all four JSON files restored." >&2
            return 0
        fi
    done
    for svc in ws upgrade xhttp grpc; do
        if systemctl is-active --quiet "xray@$svc" 2>/dev/null; then
            systemctl restart "xray@$svc" 2>/dev/null || true
        fi
    done
    fix_log "fix536: replaced published default Xray credentials"
    fix_marker .fix536-default-creds
    echo "Fix 536: published default Xray credentials replaced; Xray units restarted."
}

# Found 539: the old templates used a client object as the insertion anchor.
# The account scripts now insert through /usr/bin/xray-add-client, so remove
# those anchor objects from existing boxes.  The Python pass edits the text
# directly because the JSON files intentionally contain # comment markers.
remove_template_client_anchors() {
    local marker="/etc/funny/.fix539-client-anchors"
    local dir="/etc/xray/json"
    local files="$dir/ws.json $dir/upgrade.json $dir/xhttp.json $dir/grpc.json"
    local f
    [ -f "$marker" ] && return 0
    command -v xray >/dev/null 2>&1 || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    for f in $files; do
        [ -f "$f" ] || return 0
    done
    mkdir -p "$BACKUP/json" 2>/dev/null || return 0
    for f in $files; do
        cp -f "$f" "$BACKUP/json/$(basename "$f")" 2>/dev/null || true
    done
    python3 - $files <<'PY'
import re
import sys
from pathlib import Path

for name in sys.argv[1:]:
    path = Path(name)
    lines = path.read_text().splitlines(keepends=True)
    removed = 0
    while True:
        idx = None
        for i, line in enumerate(lines):
            if line.strip() in ("#vless", "#vmess", "#trojan"):
                idx = i
                break
        if idx is None:
            break
        start = None
        for i in range(idx - 1, -1, -1):
            if lines[i].strip() == "{":
                start = i
                break
        end = None
        for i in range(idx + 1, len(lines)):
            if lines[i].strip() in ("}", "},"):
                end = i
                break
        if start is None or end is None:
            sys.exit(f"template anchor is not a complete object in {name}")
        del lines[start:end + 1]
        removed += 1
    text = "".join(lines)
    text = re.sub(r"},\n *\]", "}\n        ]", text)
    path.write_text(text)
    if removed:
        print(f"Fix 539: removed {removed} template client anchors from {name}.")
PY
    if [ "$?" -ne 0 ]; then
        for f in $files; do
            cp -f "$BACKUP/json/$(basename "$f")" "$f" 2>/dev/null || true
        done
        echo "Fix 539: anchor removal failed; all four JSON files restored." >&2
        return 0
    fi
    for f in $files; do
        if ! xray run -test -config "$f" >/dev/null 2>&1; then
            for f in $files; do
                cp -f "$BACKUP/json/$(basename "$f")" "$f" 2>/dev/null || true
            done
            echo "Fix 539: Xray rejected $f after anchor removal; all four JSON files restored." >&2
            return 0
        fi
    done
    for f in ws upgrade xhttp grpc; do
        if systemctl is-active --quiet "xray@$f" 2>/dev/null; then
            systemctl restart "xray@$f" 2>/dev/null || true
        fi
    done
    fix_log "fix539: removed template client anchors"
    fix_marker .fix539-client-anchors
    echo "Fix 539: template client anchors removed; Xray units restarted."
}

# Found 537: Fix 532 stopped new cron mail but left the accumulated mbox.
# Compress it first, verify the archive, then truncate the same inode so the
# owner/mode stay correct for the local MTA.
_archive_and_truncate_mailbox() {
    local box="$1" tag="$2" stamp="$3"
    local size="" archive="" tmp=""
    [ -f "$box" ] || return 0
    size=$(stat -c %s "$box" 2>/dev/null) || return 0
    [[ "$size" =~ ^[0-9]+$ ]] || return 0
    [ "$size" -gt 1048576 ] || return 0
    archive="/root/fn-mail-backup-${tag}${stamp}.gz"
    tmp="${archive}.tmp"
    if ! gzip -c "$box" > "$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null || true
        echo "Fix 537: could not archive $box; mailbox left unchanged." >&2
        return 1
    fi
    if ! gzip -t "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp" 2>/dev/null || true
        echo "Fix 537: archive verification failed for $box; mailbox left unchanged." >&2
        return 1
    fi
    if ! mv -f "$tmp" "$archive" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null || true
        return 1
    fi
    chmod 600 "$archive" 2>/dev/null || true
    mkdir -p "$BACKUP" 2>/dev/null || true
    ln "$archive" "$BACKUP/$(basename "$archive")" 2>/dev/null || \
        cp -f "$archive" "$BACKUP/$(basename "$archive")" 2>/dev/null || true
    if ! : > "$box" 2>/dev/null; then
        echo "Fix 537: could not truncate $box; archive kept at $archive." >&2
        return 1
    fi
    fix_log "fix537: archived ${size} bytes from ${box} to ${archive}"
    echo "Fix 537: archived ${size} bytes from ${box} to ${archive}; mailbox truncated."
    return 0
}

cleanup_root_mail() {
    local marker="/etc/funny/.fix537-mail-cleared"
    local stamp="" rc=0
    [ -f "$marker" ] && return 0
    stamp=$(date +%Y%m%d-%H%M%S)
    _archive_and_truncate_mailbox "/var/mail/mail" "" "$stamp" || rc=1
    if [ -f /var/spool/mail/mail ] && ! [ /var/spool/mail/mail -ef /var/mail/mail ]; then
        _archive_and_truncate_mailbox "/var/spool/mail/mail" "spool-" "$stamp" || rc=1
    fi
    [ "$rc" -eq 0 ] && fix_marker .fix537-mail-cleared
}

# Found 540: Fix 538 removed the stale rohcuan limit once, but the old
# limit-ip-ssh enrolled every UID >= 1000 and recreated it on the next tick.
# The new limiter only enrolls panel accounts; remove the recreated copy once.
remove_stale_rohcuan_limit() {
    local marker="/etc/funny/.fix540-rohcuan-limit"
    local limit="/etc/xray/limit/ip/ssh/rohcuan"
    local card="/var/log/create/ssh/rohcuan.log"
    [ -f "$marker" ] && return 0
    [ -f "$limit" ] || return 0
    if [ -f "$card" ]; then
        fix_marker .fix538-rohcuan-limit
        return 0
    fi
    getent passwd rohcuan >/dev/null 2>&1 || {
        fix_marker .fix538-rohcuan-limit
        return 0
    }
    mkdir -p "$BACKUP" 2>/dev/null || true
    cp -f "$limit" "$BACKUP/rohcuan-limit" 2>/dev/null || true
    if ! rm -f "$limit" 2>/dev/null; then
        echo "Fix 538: could not remove $limit; file left unchanged." >&2
        return 0
    fi
    fix_log "fix540: removed recreated rohcuan SSH IP limit"
    fix_marker .fix540-rohcuan-limit
    echo "Fix 540: removed recreated rohcuan SSH IP limit (OS user untouched)."
}

# Found 541: deleting a rotated domain now removes its certificate and
# ACME/Certbot state.  Existing boxes can still carry SAN names that were
# removed from the list earlier, so rebuild the self-signed certificate from
# the current installer+rotated set once.  Reload only; never restart.
cleanup_domain_cert_remnants() {
    local marker="/etc/funny/.fix541-domain-cleanup"
    local cert="/etc/xray/xray.crt"
    local key="/etc/xray/xray.key"
    local installer names san d extras subj iss
    [ -f "$marker" ] && return 0
    [ -s "$cert" ] && [ -s "$key" ] || return 0
    command -v openssl >/dev/null 2>&1 || return 0
    command -v nginx >/dev/null 2>&1 || return 0
    installer=$(tr -d '[:space:]' < /etc/xray/installer-domain 2>/dev/null || true)
    names=$(
        {
            [ -n "$installer" ] && printf '%s\n' "$installer"
            [ -s /etc/xray/rotated-domains ] && cat /etc/xray/rotated-domains
        } | sed 's/[[:space:]]//g' | awk 'NF && !seen[$0]++ {printf "%s ", $0}'
    )
    names=${names% }
    [ -n "$names" ] || return 0
    subj=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/^subject=//')
    iss=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/^issuer=//')
    if [ -z "$subj" ] || [ "$subj" != "$iss" ]; then
        fix_log "fix541: CA-issued certificate left unchanged"
        fix_marker .fix541-domain-cleanup
        return 0
    fi
    extras=""
    for d in $(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null \
        | tr ',' '\n' | sed -n 's/.*DNS://p' | sed 's/[[:space:]]//g'); do
        case " $names " in
            *" $d "*) ;;
            *) extras="$extras $d" ;;
        esac
    done
    extras=${extras# }
    if [ -z "$extras" ]; then
        fix_log "fix541: certificate SAN already clean"
        fix_marker .fix541-domain-cleanup
        return 0
    fi
    mkdir -p "$BACKUP/domain-cleanup" 2>/dev/null || return 0
    cp -f "$cert" "$BACKUP/domain-cleanup/xray.crt" 2>/dev/null || true
    cp -f "$key" "$BACKUP/domain-cleanup/xray.key" 2>/dev/null || true
    [ -f /etc/haproxy/funny.pem ] && cp -f /etc/haproxy/funny.pem "$BACKUP/domain-cleanup/funny.pem" 2>/dev/null || true
    san=""
    for d in $names; do san="$san,DNS:$d"; done
    san="${san#,}"
    if ! openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 365 -nodes -x509 \
        -subj "/CN=${installer:-${names%% *}}" -addext "subjectAltName=$san" \
        -keyout /etc/xray/.fix541.key.tmp -out /etc/xray/.fix541.crt.tmp >/dev/null 2>&1; then
        rm -f /etc/xray/.fix541.key.tmp /etc/xray/.fix541.crt.tmp 2>/dev/null || true
        echo "Fix 541: certificate generation failed; files left unchanged." >&2
        return 0
    fi
    mv -f /etc/xray/.fix541.crt.tmp "$cert"
    mv -f /etc/xray/.fix541.key.tmp "$key"
    chmod 644 "$cert" 2>/dev/null || true
    chmod 600 "$key" 2>/dev/null || true
    if [ -f /etc/haproxy/haproxy.cfg ]; then
        cat "$cert" "$key" > /etc/haproxy/.funny.pem.tmp 2>/dev/null \
            && mv -f /etc/haproxy/.funny.pem.tmp /etc/haproxy/funny.pem 2>/dev/null || true
        chmod 600 /etc/haproxy/funny.pem 2>/dev/null || true
    fi
    if ! nginx -t >/dev/null 2>&1; then
        cp -f "$BACKUP/domain-cleanup/xray.crt" "$cert" 2>/dev/null || true
        cp -f "$BACKUP/domain-cleanup/xray.key" "$key" 2>/dev/null || true
        if [ -f "$BACKUP/domain-cleanup/funny.pem" ]; then
            cp -f "$BACKUP/domain-cleanup/funny.pem" /etc/haproxy/funny.pem 2>/dev/null || true
        fi
        echo "Fix 541: nginx rejected the rebuilt certificate; files restored." >&2
        return 0
    fi
    for d in $extras; do
        [[ "$d" =~ ^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$ ]] || continue
        rm -rf "/etc/letsencrypt/live/$d" "/etc/letsencrypt/archive/$d" "/etc/letsencrypt/renewal/$d.conf" 2>/dev/null || true
        rm -rf "/root/.acme.sh/$d" "/root/.acme.sh/${d}_ecc" 2>/dev/null || true
    done
    systemctl reload nginx 2>/dev/null || true
    if [ -f /etc/haproxy/haproxy.cfg ] && command -v haproxy >/dev/null 2>&1 && systemctl is-active --quiet haproxy 2>/dev/null; then
        haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 && systemctl reload haproxy 2>/dev/null || true
    fi
    fix_log "fix541: removed stale certificate SAN entries: $extras"
    fix_marker .fix541-domain-cleanup
    echo "Fix 541: removed stale certificate SAN entries: $extras"
}

# Run the state migrations before the service restarts below.  Xray must be
# valid before it is restarted (Fix 536/539), while the quota files (Fix 535)
# are read on the next pass and need no restart of their own.
neutralize_default_credentials
remove_template_client_anchors
cleanup_domain_cert_remnants
repair_simpang32
sync_dnstt_unit
install_dnstt_null_support
remove_stale_rohcuan_limit
cleanup_root_mail
restart_quota_services

# Banner wiring (installer/ssh.sh equivalent for existing boxes):
# OpenSSH shows /etc/issue.net only when named; Dropbear only with -b.
# The banner CONTENT is never touched here (operator custom stays).
wired=0
if [ -f /etc/ssh/sshd_config ] && ! grep -qE "^[[:space:]]*Banner[[:space:]]+" /etc/ssh/sshd_config 2>/dev/null; then
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config && wired=1
fi
if grep -qE '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear 2>/dev/null && \
   ! grep -qE '\-b[[:space:]]+/etc/issue.net' /etc/default/dropbear 2>/dev/null; then
    sed -i -E 's|^(DROPBEAR_EXTRA_ARGS="[^"]*)"|\1 -b /etc/issue.net"|' /etc/default/dropbear && wired=1
fi
if [ "$wired" -eq 1 ]; then
    if command -v sshd >/dev/null 2>&1; then sshd -t 2>/dev/null && systemctl restart ssh 2>/dev/null || true; fi
    command -v systemctl >/dev/null 2>&1 && systemctl restart dropbear 2>/dev/null || true
    echo "Banner wiring applied (ssh/dropbear restarted; dropbear clients reconnect)."
fi

# Found 514: the 777 TLS front-end forwards to Dropbear from 127.0.0.1.
# Enable HAProxy's start-of-session TCP log so ssh-online can map those
# sessions to the real client IP, like it already does for ws.
patch_haproxy_logging() {
    local conf="${FN_HAPROXY_CONF:-/etc/haproxy/haproxy.cfg}"
    [ "$EDITION" = "full" ] || return 0
    [ -f "$conf" ] || return 0
    # Found 519: check the directives in the section that actually uses them.
    # A `log global` in another frontend must not make the ssh-ssl frontend
    # look configured; without its own `log global`, HAProxy emits no 777
    # session line and ssh-online cannot map the client IP.
    _haproxy_global_has_log() {
        awk '
            BEGIN { in_g = 0; found = 0 }
            /^[[:space:]]*global[[:space:]]*$/ { in_g = 1; next }
            in_g && /^[^[:space:]#]/ { in_g = 0 }
            in_g && /^[[:space:]]*log[[:space:]]/ { found = 1 }
            END { exit(found ? 0 : 1) }
        ' "$conf"
    }
    _haproxy_sshssl_has() {
        awk -v re="$1" '
            BEGIN { in_fe = 0; found = 0 }
            /^[[:space:]]*frontend[[:space:]]+ssh-ssl([[:space:]]|$)/ {
                in_fe = 1
                next
            }
            in_fe && /^[^[:space:]#]/ { in_fe = 0 }
            in_fe && $0 ~ re { found = 1 }
            END { exit(found ? 0 : 1) }
        ' "$conf"
    }
    # Found 533: `option tcplog` is valid in a frontend/listen section, but
    # HAProxy ignores it in a backend and warns on every `haproxy -c`.  The
    # ssh-backend already inherits TCP logging from the ssh-ssl frontend.
    _haproxy_backend_has_tcplog() {
        awk '
            BEGIN { in_be = 0; found = 0 }
            /^[[:space:]]*backend[[:space:]]+ssh-backend([[:space:]]|$)/ {
                in_be = 1
                next
            }
            in_be && /^[^[:space:]#]/ { in_be = 0 }
            in_be && /^[[:space:]]*option[[:space:]]+tcplog[[:space:]]*$/ { found = 1 }
            END { exit(found ? 0 : 1) }
        ' "$conf"
    }
    local need_log=0 need_asap=0 need_global=0 need_tcplog=0
    _haproxy_global_has_log || need_log=1
    _haproxy_sshssl_has '^[[:space:]]*option[[:space:]]+logasap[[:space:]]*$' || need_asap=1
    _haproxy_sshssl_has '^[[:space:]]*log[[:space:]]+global[[:space:]]*$' || need_global=1
    if _haproxy_backend_has_tcplog; then need_tcplog=1; fi
    [ "${need_log}${need_asap}${need_global}${need_tcplog}" = "0000" ] && return 0
    cp -f "$conf" "$BACKUP/haproxy.cfg" || return 0

    if [ "$need_log" -eq 1 ]; then
        awk '
            BEGIN { done = 0 }
            /^[[:space:]]*global[[:space:]]*$/ && !done {
                print
                print "    log /dev/log local0"
                done = 1
                next
            }
            { print }
        ' "$conf" > "$conf.fn-new" || { rm -f "$conf.fn-new"; return 0; }
        mv "$conf.fn-new" "$conf"
    fi

    if [ "$need_asap" -eq 1 ]; then
        awk -v add_global="$need_global" '
            BEGIN { in_fe = 0; done = 0 }
            /^[[:space:]]*frontend[[:space:]]+ssh-ssl([[:space:]]|$)/ {
                in_fe = 1
                print
                next
            }
            in_fe && /^[^[:space:]#]/ { in_fe = 0 }
            in_fe && /^[[:space:]]*option[[:space:]]+tcplog[[:space:]]*$/ && !done {
                print
                print "    option logasap"
                if (add_global == 1) print "    log global"
                done = 1
                next
            }
            in_fe && /^[[:space:]]*default_backend[[:space:]]/ && !done {
                print "    option tcplog"
                print "    option logasap"
                if (add_global == 1) print "    log global"
                done = 1
            }
            { print }
        ' "$conf" > "$conf.fn-new" || { rm -f "$conf.fn-new"; return 0; }
        mv "$conf.fn-new" "$conf"
    elif [ "$need_global" -eq 1 ]; then
        awk '
            BEGIN { in_fe = 0; done = 0 }
            /^[[:space:]]*frontend[[:space:]]+ssh-ssl([[:space:]]|$)/ {
                in_fe = 1
                print
                next
            }
            in_fe && /^[^[:space:]#]/ { in_fe = 0 }
            in_fe && /^[[:space:]]*default_backend[[:space:]]/ && !done {
                print "    log global"
                done = 1
            }
            { print }
        ' "$conf" > "$conf.fn-new" || { rm -f "$conf.fn-new"; return 0; }
        mv "$conf.fn-new" "$conf"
    fi

    if [ "$need_tcplog" -eq 1 ]; then
        awk '
            BEGIN { in_be = 0 }
            /^[[:space:]]*backend[[:space:]]+ssh-backend([[:space:]]|$)/ {
                in_be = 1
                print
                next
            }
            in_be && /^[^[:space:]#]/ { in_be = 0 }
            in_be && /^[[:space:]]*option[[:space:]]+tcplog[[:space:]]*$/ { next }
            { print }
        ' "$conf" > "$conf.fn-new" || { rm -f "$conf.fn-new"; return 0; }
        mv "$conf.fn-new" "$conf"
    fi

    if ! _haproxy_global_has_log || \
        ! _haproxy_sshssl_has '^[[:space:]]*option[[:space:]]+logasap[[:space:]]*$' || \
        ! _haproxy_sshssl_has '^[[:space:]]*log[[:space:]]+global[[:space:]]*$' || \
        _haproxy_backend_has_tcplog; then
        cp -f "$BACKUP/haproxy.cfg" "$conf"
        echo "HAProxy logging/cleanup directives could not be placed; config restored." >&2
        return 0
    fi
    if command -v haproxy >/dev/null 2>&1 && ! haproxy -c -f "$conf" >/dev/null 2>&1; then
        cp -f "$BACKUP/haproxy.cfg" "$conf"
        echo "HAProxy logging patch rejected by haproxy -c; config restored." >&2
        return 0
    fi
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy 2>/dev/null || true
    fi
    echo "HAProxy 777 logging enabled (client IP evidence for ssh-online)."
}
patch_haproxy_logging

# Found 523: fresh installs before the fix wrote "Unknown" to .install-commit
# because the GitHub API endpoint was wrong. FROM is the best known live
# version. When the install marker is missing/invalid and this update actually
# changes the version, record FROM as the baseline so the menu can show both
# the version the box came from and the version it now runs. A same-target
# rerun leaves the marker alone.
_prev_install=""
[ -r /etc/funny/.install-commit ] && _prev_install=$(tr -d '[:space:]' < /etc/funny/.install-commit 2>/dev/null)
case "$_prev_install" in
    ""|Unknown|unknown)
        case "$FROM" in
            *[!0-9a-f]*|"") ;;
            *)
                if [ ${#FROM} -eq 40 ] && [ "$FROM" != "$TARGET" ]; then
                    printf '%s\n' "$FROM" > /etc/funny/.install-commit
                    chmod 600 /etc/funny/.install-commit 2>/dev/null || true
                fi
                ;;
        esac
        ;;
esac

echo "$TARGET" > /etc/funny/.update-commit
chmod 600 /etc/funny/.update-commit 2>/dev/null || true

echo ""
echo "UPDATE SUCCESS: ${FROM:0:7} -> ${TARGET:0:7} ($EDITION)"
echo "Backup of replaced files: $BACKUP"
echo "Cron/menu scripts need no restart; ssh/dropbear restarted only if banner wiring was missing."
