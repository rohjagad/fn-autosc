#!/bin/bash
# Found 546: cap system-log retention without lowering Xray's info level.
# Installed as /usr/bin/log-caps on both editions and run by the fresh
# installers and by update.sh.  The rsyslog stanza is edited in place because
# a second stanza for /var/log/syslog is a duplicate log entry.
#
# Policy: daily rotation, 7 generations, 1G emergency size trigger; journald
# capped at 2G with 100M files.  The change is idempotent: a second run changes
# no file and forces no rotation.  The original rsyslog stanza is saved under
# $BACKUP, or a timestamped /root directory when run outside update.sh.

set -u

BACKUP="${BACKUP:-/root/fn-log-cap-backup-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP" 2>/dev/null || true

apply_log_caps() {
    local conf="/etc/logrotate.d/rsyslog"
    local jconf="/etc/systemd/journald.conf.d/99-fn-autosc-log-cap.conf"
    local tmp="" dry="" changed=0 jchanged=0 has_max=0

    if [ -f "$conf" ] && command -v logrotate >/dev/null 2>&1 && \
       tmp=$(mktemp) && dry=$(mktemp); then
        grep -qE '^[[:space:]]*maxsize[[:space:]]+' "$conf" && has_max=1
        if awk -v has_max="$has_max" '
            /^[[:space:]]*weekly[[:space:]]*$/ { print "\tdaily"; next }
            /^[[:space:]]*rotate[[:space:]]+[0-9]+[[:space:]]*$/ {
                if (!saw_rotate) {
                    print "\trotate 7"
                    if (!has_max) print "\tmaxsize 1G"
                    saw_rotate = 1
                }
                next
            }
            /^[[:space:]]*maxsize[[:space:]]+/ { print "\tmaxsize 1G"; next }
            /^[[:space:]]*}[[:space:]]*$/ {
                if (!saw_rotate) {
                    print "\trotate 7"
                    if (!has_max) print "\tmaxsize 1G"
                    saw_rotate = 1
                }
                print
                next
            }
            { print }
            END {
                if (!saw_rotate) {
                    print "\trotate 7"
                    if (!has_max) print "\tmaxsize 1G"
                }
            }
        ' "$conf" > "$tmp"; then
            if ! cmp -s "$conf" "$tmp"; then
                cp -p "$conf" "$BACKUP/rsyslog.logrotate" 2>/dev/null || true
                if cat "$tmp" > "$conf"; then
                    changed=1
                else
                    cp -p "$BACKUP/rsyslog.logrotate" "$conf" 2>/dev/null || true
                fi
            fi
        fi
        if [ "$changed" -eq 1 ]; then
            if ! logrotate -d "$conf" > "$dry" 2>&1 || grep -qiE '^[[:space:]]*error:' "$dry"; then
                cp -p "$BACKUP/rsyslog.logrotate" "$conf" 2>/dev/null || true
                echo "log caps: logrotate rejected the rsyslog policy; restored." >&2
                changed=0
            fi
        fi
        rm -f "$tmp" "$dry"
        if [ "$changed" -eq 1 ]; then
            if logrotate -f "$conf" >/dev/null 2>&1; then
                echo "log caps: rsyslog is daily/rotate 7/maxsize 1G (one rotation forced)."
            else
                echo "log caps: rsyslog policy installed; forced rotation failed, next daily run applies." >&2
            fi
        fi
    fi

    if command -v systemctl >/dev/null 2>&1 && command -v journalctl >/dev/null 2>&1 && \
       mkdir -p /etc/systemd/journald.conf.d 2>/dev/null; then
        if [ ! -f "$jconf" ] || \
           ! grep -qx 'SystemMaxUse=2G' "$jconf" 2>/dev/null || \
           ! grep -qx 'SystemMaxFileSize=100M' "$jconf" 2>/dev/null; then
            [ -f "$jconf" ] && cp -p "$jconf" "$BACKUP/journald-log-cap.conf" 2>/dev/null || true
            if printf '%s\n' '[Journal]' 'SystemMaxUse=2G' 'SystemMaxFileSize=100M' > "$jconf"; then
                chmod 644 "$jconf" 2>/dev/null || true
                jchanged=1
            fi
        fi
    fi
    if [ "$jchanged" -eq 1 ]; then
        if systemctl restart systemd-journald >/dev/null 2>&1; then
            journalctl --vacuum-size=2G >/dev/null 2>&1 || true
            echo "log caps: journald capped at 2G (100M files)."
        else
            echo "log caps: journald drop-in installed; restart failed, applies on next boot." >&2
        fi
    fi
}

apply_log_caps
mkdir -p /etc/funny 2>/dev/null || true
: > /etc/funny/.fix546-log-caps 2>/dev/null || true
chmod 600 /etc/funny/.fix546-log-caps 2>/dev/null || true
exit 0
