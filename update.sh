#!/bin/bash
#
# FN AutoSC updater: 6b967af -> 2833d8d
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
# with per-domain account counts)
# to a live install. The file set is a superset covering the earlier
# ranges too, so older installs are brought fully up to date in one
# run. Safe to run: files are backed up first, every download is
# verified before it replaces anything, and cron/menu scripts need no
# restart (only ssh/dropbear restart, and only if banner wiring was
# missing).
#
# Usage:
#   bash update.sh                  # live marker -> 2833d8d (default)
#   bash update.sh <commit> --force  # re-apply even if already recorded
#
# One-line remote run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)

set -u

# Fallback baseline: the live v1.23 install (Found 520).  The real starting
# version is read from the live panel below, so this value only appears when
# both markers are missing.
FROM="6b967af9e0ebadc76a265132e49d62a27ad72235"
TARGET="${1:-2833d8d03dc9f1cd22e0b2a130a417c18877be6a}"
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
FILES="xp limit-ip-ws limit-ip-http limit-ip-xhttp limit-ip-grpc
delete-ws delete-xhttp menu-system menu backup bmenu dm-menu
add-trojan-grpc add-trojan-http add-trojan-ws add-trojan-xhttp add-vless-grpc add-vless-http add-vless-ws add-vless-xhttp add-vmess-grpc add-vmess-http add-vmess-ws add-vmess-xhttp trial-trojan-grpc trial-trojan-http trial-trojan-ws trial-trojan-xhttp trial-vless-grpc trial-vless-http trial-vless-ws trial-vless-xhttp trial-vmess-grpc trial-vmess-http trial-vmess-ws trial-vmess-xhttp
unlock-ws-auto unlock-http-auto unlock-xhttp-auto unlock-grpc-auto"
# format.sh lives in config/ and installs to /etc/funny, not /usr/bin.
CONFIG_FILES="format.sh"
# Found 514: /usr/bin/restore-ftp is the non-interactive website variant
# installed by website/install.sh (it reads /var/www/uploads/*.zip).  The
# full/lite restore-ftp.sh files carry the license gate and TUI prompts and
# must not overwrite it on a live box.
WEB_FILES="restore-ftp"
if [ "$EDITION" = "full" ]; then
    FILES="$FILES addssh trial-ssh menu-wg xl2tp menu-noobz limit-ip-ssh cek-login-ssh ssh-online menu-ssh"
else
    # Lite only: this viewer used to truncate ws.log at the end (Found 508).
    FILES="$FILES cek-xray-ws"
fi

# Expected marker per file: proves the download is the fixed version.
marker_for() {
    case "$1" in
        xp) echo 'Fix 517' ;;
        limit-ip-ssh) echo 'ssh_auto_unlock' ;;
        cek-login-ssh) echo 'WS/HAProxy mapping unavailable' ;;
        ssh-online) echo 'HAPROXY_TOL_US' ;;
        menu-ssh) echo 'haproxy -v' ;;
        cek-xray-ws) echo 'Found 508: keep the access log' ;;
        backup | restore-ftp | bmenu) echo 'Found 511' ;;
        format.sh) echo 'Press any key to return...' ;;
        limit-ip-*) echo 'keep the original epoch' ;;
        unlock-*-auto) echo 'invalid locked card for $user' ;;
        delete-ws) echo 'Delete WS Account' ;;
        delete-xhttp) echo 'Delete XHTTP Account' ;;
        menu-system) echo 'Banner /etc/issue.net' ;;
        menu) echo 'Installed version' ;;
        dm-menu | menu-wg | xl2tp | menu-noobz) echo 'Installer Domain' ;;
        add-* | trial-*) echo 'Rotated Domain' ;;
        addssh | trial-ssh) echo 'Rotated Domain' ;;
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
    local need_log=0 need_asap=0 need_global=0
    _haproxy_global_has_log || need_log=1
    _haproxy_sshssl_has '^[[:space:]]*option[[:space:]]+logasap[[:space:]]*$' || need_asap=1
    _haproxy_sshssl_has '^[[:space:]]*log[[:space:]]+global[[:space:]]*$' || need_global=1
    [ "${need_log}${need_asap}${need_global}" = "000" ] && return 0
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

    if ! _haproxy_global_has_log || \
        ! _haproxy_sshssl_has '^[[:space:]]*option[[:space:]]+logasap[[:space:]]*$' || \
        ! _haproxy_sshssl_has '^[[:space:]]*log[[:space:]]+global[[:space:]]*$'; then
        cp -f "$BACKUP/haproxy.cfg" "$conf"
        echo "HAProxy logging directives could not be placed; 777 mapping not enabled." >&2
        return 0
    fi
    if command -v haproxy >/dev/null 2>&1 && ! haproxy -c -f "$conf" >/dev/null 2>&1; then
        cp -f "$BACKUP/haproxy.cfg" "$conf"
        echo "HAProxy logging patch rejected by haproxy -c; config restored." >&2
        return 0
    fi
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        systemctl restart haproxy 2>/dev/null || true
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
