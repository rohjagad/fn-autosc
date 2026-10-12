#!/bin/bash
#
# FN AutoSC updater: 5c48741 -> 6b967af
#
# Applies the commits on top of b6d1a97 (1-minute evidence window,
# Exp-Date-N/A binary fix, LOCKED IPs block, MULTILOGIN UNLOCKED
# notices, SSH Time Login block, working SSH banner wiring + default)
# to a live install. The file set is a superset covering the earlier
# ranges too, so older installs are brought fully up to date in one
# run. Safe to run: files are backed up first, every download is
# verified before it replaces anything, and cron/menu scripts need no
# restart (only ssh/dropbear restart, and only if banner wiring was
# missing).
#
# Usage:
#   bash update.sh                  # update to 6b967af (default)
#   bash update.sh <commit> --force  # re-apply even if already recorded
#
# One-line remote run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)

set -u

FROM="5c487410db77000968450495a615f8e7971f376a"
TARGET="${1:-6b967af9e0ebadc76a265132e49d62a27ad72235}"
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
command -v unzip >/dev/null 2>&1 || {
    apt-get update -qq && apt-get install -y unzip
}
fetch() {
    # $1=url $2=dest $3=timeout seconds (default 60; the ~60 MB menu zip
    # gets a long one - VPS links to GitHub are sometimes slow).
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

# Deployed name (no .sh) -> repo source name.
FILES="limit-ip-ws limit-ip-http limit-ip-xhttp limit-ip-grpc
delete-ws delete-xhttp menu-system menu
add-vmess-ws add-vmess-http add-vmess-xhttp add-vmess-grpc
trial-vmess-ws trial-vmess-http trial-vmess-xhttp trial-vmess-grpc
unlock-ws-auto unlock-http-auto unlock-xhttp-auto unlock-grpc-auto"
if [ "$EDITION" = "full" ]; then
    FILES="$FILES addssh trial-ssh limit-ip-ssh"
fi

# Expected marker per file: proves the download is the fixed version.
marker_for() {
    case "$1" in
        limit-ip-ssh) echo 'MULTILOGIN UNLOCKED' ;;
        limit-ip-*) echo 'IPs (${_logc})' ;;
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
ZIPURL="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/menu/${EDITION}.zip"

# change-limit-ip tools ship as compiled binaries inside the menu zip
# (no .sh to syntax-check), so they travel separately with pinned
# md5 fingerprints per edition instead of text markers.
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

# Phase 1b: binaries via the edition menu zip (integrity + md5 verified).
echo "Downloading menu zip (${EDITION})..."
fetch "$ZIPURL" "${STAGE}/menu.zip" 600 || {
    echo "FAILED to download menu zip - aborting, nothing changed."
    rm -rf "$STAGE"
    exit 1
}
unzip -t -q "${STAGE}/menu.zip" >/dev/null 2>&1 || {
    echo "Menu zip failed integrity test - aborting, nothing changed."
    rm -rf "$STAGE"
    exit 1
}
for b in $BINARIES; do
    unzip -q -p "${STAGE}/menu.zip" "$b" > "${STAGE}/${b}" 2>/dev/null || {
        echo "FAILED to extract $b - aborting, nothing changed."
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
