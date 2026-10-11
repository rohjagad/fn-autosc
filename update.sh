#!/bin/bash
#
# FN AutoSC updater: b6d1a97 -> 5c48741
#
# Applies the notice-improvement commits on top of b6d1a97 (LOCKED IPs
# block, MULTILOGIN UNLOCKED notices for Xray + SSH, SSH Time Login
# block) to a live install. The file set is a superset that also covers
# the earlier b91281c range, so older installs are brought fully up to
# date in one run. Safe to run: files are backed up first, every
# download is syntax-checked before it replaces anything, and no
# service restart is needed (cron jobs and menus read these files
# fresh on every run).
#
# Usage:
#   bash update.sh                  # update to 5c48741 (default)
#   bash update.sh <commit> --force  # re-apply even if already recorded
#
# One-line remote run:
#   bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)

set -u

FROM="b6d1a97376979c8ef7aea51a5ef10aed65ae1437"
TARGET="${1:-5c487410db77000968450495a615f8e7971f376a}"
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
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 60 "$1" -o "$2"
    else
        wget -q --timeout=60 -O "$2" "$1"
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
delete-ws delete-xhttp menu-system
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
        add-vmess-* | trial-vmess-*) echo '"sni": "${rdomain}"' ;;
        addssh | trial-ssh) echo 'Rotated' ;;
    esac
}

BACKUP="/root/fn-update-backup-$(date +%Y%m%d-%H%M%S)"
STAGE=$(mktemp -d) || { echo "Cannot create staging dir."; exit 1; }
BASE="https://raw.githubusercontent.com/rohjagad/fn-autosc/${TARGET}/${EDITION}"

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

# Phase 2: back up current files, then install.
mkdir -p "$BACKUP"
for name in $FILES; do
    [ -e "/usr/bin/${name}" ] && cp -f "/usr/bin/${name}" "${BACKUP}/${name}"
    install -m 0755 "${STAGE}/${name}" "/usr/bin/${name}"
done
rm -rf "$STAGE"

echo "$TARGET" > /etc/funny/.update-commit
chmod 600 /etc/funny/.update-commit 2>/dev/null || true

echo ""
echo "UPDATE SUCCESS: ${FROM:0:7} -> ${TARGET:0:7} ($EDITION)"
echo "Backup of replaced files: $BACKUP"
echo "No service restart was needed (cron/menu scripts load fresh)."
