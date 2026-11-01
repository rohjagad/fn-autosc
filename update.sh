#!/bin/bash
#
# FN AutoSC updater: 5c48741 -> 394059b
#
# Applies the commits on top of b6d1a97 (1-minute evidence window,
# Exp-Date-N/A binary fix, LOCKED IPs block, MULTILOGIN UNLOCKED
# notices, working SSH banner wiring + default, xp lock-in-flight +
# empty-expiry guard, IP evidence map + CGNAT stable-set gate, Xray
# auto-unlock at least 15 minutes, restore version-marker/formatter
# guard, SSH active-IP limit/display with real WS/CDN client IPs)
# to a live install. The file set is a superset covering the earlier
# ranges too, so older installs are brought fully up to date in one
# run. Safe to run: files are backed up first, every download is
# verified before it replaces anything, and cron/menu scripts need no
# restart (only ssh/dropbear restart, and only if banner wiring was
# missing).
#
# Usage:
#   bash update.sh                  # update to 394059b (default)
#   bash update.sh <commit> --force  # re-apply even if already recorded
#
# One-line remote run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)

set -u

FROM="5c487410db77000968450495a615f8e7971f376a"
TARGET="${1:-394059bf79ee2d0501998b98234e7866ccfd971f}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

# Downloader (same bootstrap the README install command uses).
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
    apt-get update -qq && apt-get install -y curl
}
fetch() {
    # $1=url $2=dest $3=timeout seconds (default 60; large payload binaries
    # get a longer one - VPS links to GitHub are sometimes slow).
    local _timeout="${3:-60}"
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

# Found 512: the SSH IP limiter/menu use the ssh-online helper (stdlib Python)
# to resolve WS/CDN clients to their real IPs.
if [ "$EDITION" = "full" ] && ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for ssh-online (SSH IP limit). Install python3 first." >&2
    exit 1
fi

# Deployed name (no .sh) -> repo source name.
FILES="xp limit-ip-ws limit-ip-http limit-ip-xhttp limit-ip-grpc
delete-ws delete-xhttp menu-system menu backup restore-ftp bmenu
add-vmess-ws add-vmess-http add-vmess-xhttp add-vmess-grpc
trial-vmess-ws trial-vmess-http trial-vmess-xhttp trial-vmess-grpc
unlock-ws-auto unlock-http-auto unlock-xhttp-auto unlock-grpc-auto"
# format.sh lives in config/ and installs to /etc/funny, not /usr/bin.
CONFIG_FILES="format.sh"
if [ "$EDITION" = "full" ]; then
    FILES="$FILES addssh trial-ssh limit-ip-ssh cek-login-ssh ssh-online"
else
    # Lite only: this viewer used to truncate ws.log at the end (Found 508).
    FILES="$FILES cek-xray-ws"
fi

# Expected marker per file: proves the download is the fixed version.
marker_for() {
    case "$1" in
        xp) echo 'xp_lock_in_flight' ;;
        limit-ip-ssh) echo 'MULTILOGIN UNLOCKED' ;;
        cek-login-ssh | ssh-online) echo 'Found 512' ;;
        cek-xray-ws) echo 'Found 508: keep the access log' ;;
        backup | restore-ftp | bmenu) echo 'Found 511' ;;
        format.sh) echo 'Press any key to return...' ;;
        limit-ip-*) echo 'statsonlineiplist' ;;
        unlock-*-auto) echo 'MULTILOGIN UNLOCKED' ;;
        delete-ws) echo 'Delete WS Account' ;;
        delete-xhttp) echo 'Delete XHTTP Account' ;;
        menu-system) echo 'Banner /etc/issue.net' ;;
        menu) echo 'Installed version' ;;
        add-vmess-* | trial-vmess-*) echo '"sni": "${rdomain}"' ;;
        addssh | trial-ssh) echo 'Rotated' ;;
    esac
}

BACKUP="/root/fn-update-backup-$(date +%Y%m%d-%H%M%S)"
STAGE=$(mktemp -d) || { echo "Cannot create staging dir."; exit 1; }
BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/${EDITION}"
CONFIG_BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/config"
BIN_BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/bin/${EDITION}"

# change-limit-ip tools ship as standalone compiled binaries (no .sh to
# syntax-check), so they travel separately with pinned md5 fingerprints per
# edition instead of text markers. Found 513: no menu zip anymore.
BINARIES="change-limit-ip-ws change-limit-ip-http change-limit-ip-xhttp change-limit-ip-grpc"
bin_md5() {
    if [ "$EDITION" = "full" ]; then
        case "$1" in
            change-limit-ip-ws) echo '98f5d2f80b41a8ad348514638c0120be' ;;
            change-limit-ip-http) echo 'fd1a02d7e522c9e7d89b1bee07e0a5e8' ;;
            change-limit-ip-xhttp) echo '3bf12a8521c3577abb3400400effeff3' ;;
            change-limit-ip-grpc) echo '5ed18b1ac5a98ef47531cd01474b08ed' ;;
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

# Phase 2: back up current files, then install.
mkdir -p "$BACKUP"
for name in $FILES; do
    [ -e "/usr/bin/${name}" ] && cp -f "/usr/bin/${name}" "${BACKUP}/${name}"
    install -m 0755 "${STAGE}/${name}" "/usr/bin/${name}"
done
for b in $BINARIES; do
    [ -e "/usr/bin/${b}" ] && cp -f "/usr/bin/${b}" "${BACKUP}/${b}"
    install -m 0755 "${STAGE}/${b}" "/usr/bin/${b}"
done
mkdir -p /etc/funny
for name in $CONFIG_FILES; do
    [ -e "/etc/funny/${name}" ] && cp -f "/etc/funny/${name}" "${BACKUP}/funny-${name}"
    install -m 0755 "${STAGE}/${name}" "/etc/funny/${name}"
done
rm -rf "$STAGE"

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

echo "$TARGET" > /etc/funny/.update-commit
chmod 600 /etc/funny/.update-commit 2>/dev/null || true

echo ""
echo "UPDATE SUCCESS: ${FROM:0:7} -> ${TARGET:0:7} ($EDITION)"
echo "Backup of replaced files: $BACKUP"
echo "Cron/menu scripts need no restart; ssh/dropbear restarted only if banner wiring was missing."
