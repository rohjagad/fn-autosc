#!/bin/bash
#
# ssh-online - list active SSH sessions with the real client IP.
#
# Found 512: Dropbear and OpenSSH see the direct TCP peer.  On this panel the
# SSH-over-WebSocket/CDN path is:
#
#     client -> Cloudflare -> nginx -> ws:2080 -> dropbear:109
#
# so Dropbear logs every CDN client as 127.0.0.1.  The ws proxy logs the real
# client IP immediately before it opens the target connection, but it does not
# log the SSH username.  The target connection and the Dropbear child
# connection are created within a fraction of a millisecond, so the child's
# journal timestamp identifies the matching ws log entry.
#
# The 777 TLS front-end (HAProxy) has the same 127.0.0.1 problem.  With
# `option logasap` HAProxy logs the client IP and the accept timestamp as soon
# as the backend connection is established; the same timestamp match resolves
# those sessions.  Without the logging patch the helper leaves 127.0.0.1 and
# the menu warns instead of inventing an IP.
#
# Output is one tab-separated line per active session:
#
#     <user>  <client-ip>  <Dropbear|Openssh>  <pid>
#
# A session is active when the daemon child process still exists and its
# journal/auth-log entry proves a successful login.  This is the same view for
# the limiter and the menu, so they cannot disagree.

command -v python3 >/dev/null 2>&1 || {
    echo "ssh-online: python3 is required" >&2
    exit 1
}

exec python3 - "$@" <<'PY'
import json
import ipaddress
import datetime
import os
import re
import subprocess
import time

AUTH_RE = re.compile(
    r"(?:Password|Pubkey) auth succeeded for '([^']+)' from ([^ ]+):(\d+)"
)
SSH_AUTH_RE = re.compile(
    r"Accepted (?:password|publickey|keyboard-interactive(?:/pam)?) "
    r"for ([^ ]+) from ([^ ]+) port (\d+)"
)
CHILD_RE = re.compile(r"Child connection from ([^ ]+):(\d+)")
WS_CLIENT_RE = re.compile(r"client:\s*([^,]+)")
WS_OPEN_RE = re.compile(r"opened .*127\.0\.0\.1:109")
# HAProxy `option tcplog` + `option logasap` line:
#   1.2.3.4:5678 [01/Nov/2026:12:34:56.789] ssh-ssl ssh-backend/ssh-server ...
# IPv6 clients may be logged as 2001:db8::1:5678 (split at the last colon)
# or [2001:db8::1]:5678.
HAPROXY_RE = re.compile(
    r"(\S+) "
    r"\[(\d{2})/([A-Za-z]{3})/(\d{4}):(\d{2}):(\d{2}):(\d{2})\.(\d{3})\] "
    r"ssh-ssl~? "
)
HAPROXY_LOG_PATHS = ("/var/log/haproxy.log", "/var/log/haproxy.log.1")
MONTHS = {
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
}

OPEN_TOL_US = 50_000
CLIENT_TOL_US = 50_000
# Found 516: a TLS client can spend seconds in the 777 handshake before
# HAProxy connects to Dropbear, so the accept timestamp may be far behind the
# child start.  Five seconds covers slow handshakes without matching an
# unrelated session.  The log scan gets a little extra padding.
HAPROXY_TOL_US = 5_000_000
HAPROXY_PAD_US = 6_000_000
HAPROXY_SKEW_US = 100_000
# Found 516: a client may sit at the password prompt for longer than ten
# minutes before authenticating.  The old 600-second window then hid that
# session from both the menu and the limiter, so it did not count toward the
# account's IP limit.  Keep the whole first day of a connection.
AUTH_WINDOW = 86400


def run(cmd):
    try:
        return subprocess.run(
            cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        ).stdout
    except Exception:
        return ""


def journal_entries(unit=None, pid=None, since=None, until=None):
    cmd = ["journalctl", "--no-pager", "-o", "json"]
    if unit:
        cmd += ["-u", unit]
    if pid:
        cmd += ["_PID=%d" % pid]
    if since:
        cmd += ["--since", since]
    if until:
        cmd += ["--until", until]
    for line in run(cmd).splitlines():
        try:
            obj = json.loads(line)
        except Exception:
            continue
        msg = obj.get("MESSAGE", "")
        if isinstance(msg, list):
            try:
                msg = bytes(msg).decode("utf-8", "replace")
            except Exception:
                msg = ""
        try:
            ts = int(obj.get("__REALTIME_TIMESTAMP", "0") or 0)
        except Exception:
            ts = 0
        yield ts, msg


def normalize_ip(value):
    """Canonical client IP: strip IPv6 brackets and normalize the address."""
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        value = value[1:-1]
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        return value


def listener_pids(name):
    """PIDs of daemon parents (PPid 1), not per-session children."""
    pids = []
    for pid in run(["pgrep", "-x", name]).split():
        try:
            with open(f"/proc/{pid}/stat") as fh:
                rest = fh.read().rsplit(")", 1)[1].split()
            ppid = int(rest[1])
        except Exception:
            continue
        if ppid == 1:
            pids.append(int(pid))
    return pids


def children(pid):
    return [int(x) for x in run(["pgrep", "-P", str(pid)]).split()]


def start_epoch(pid):
    """Process start time in epoch seconds, from /proc/<pid>/stat."""
    try:
        with open(f"/proc/{pid}/stat") as fh:
            rest = fh.read().rsplit(")", 1)[1].split()
        ticks = int(rest[19])
        hz = os.sysconf("SC_CLK_TCK")
        with open("/proc/uptime") as fh:
            uptime = float(fh.read().split()[0])
        return time.time() - uptime + ticks / hz
    except Exception:
        return None


def auth_for_pid(pid, start):
    """Return (child-connection, auth) journal records for one session PID.

    child-connection is (ts, peer-ip, peer-port); auth is
    (ts, user, peer-ip, peer-port).  The auth line must follow the child
    connection so a reused PID cannot inherit an older login.
    """
    since = "@%.6f" % max(0.0, start - 2)
    until = "@%.6f" % (start + AUTH_WINDOW)
    child = None
    auth = None
    for ts, msg in journal_entries(pid=pid, since=since, until=until):
        m = CHILD_RE.search(msg)
        if m:
            child = (ts, normalize_ip(m.group(1)), int(m.group(2)))
        m = AUTH_RE.search(msg)
        if m:
            auth = (ts, m.group(1), normalize_ip(m.group(2)), int(m.group(3)))
        m = SSH_AUTH_RE.search(msg)
        if m:
            auth = (ts, m.group(1), normalize_ip(m.group(2)), int(m.group(3)))
    if auth and child and auth[0] < child[0]:
        auth = None
    return child, auth


def openssh_auth_log():
    auth = {}
    for path in ("/var/log/auth.log", "/var/log/secure"):
        try:
            fh = open(path, errors="replace")
        except FileNotFoundError:
            continue
        with fh:
            for line in fh:
                m = re.search(
                    r"sshd(?:-session)?\[(\d+)\]: Accepted "
                    r"(?:password|publickey|keyboard-interactive(?:/pam)?) for "
                    r"([^ ]+) from ([^ ]+) port (\d+)",
                    line,
                )
                if m:
                    auth[int(m.group(1))] = (m.group(2), normalize_ip(m.group(3)))
        break
    return auth


def dropbear_auth_log():
    """Fallback for boxes where dropbear logs to auth.log instead of journald."""
    auth = {}
    for path in ("/var/log/auth.log", "/var/log/secure"):
        try:
            fh = open(path, errors="replace")
        except FileNotFoundError:
            continue
        with fh:
            for line in fh:
                m = re.search(
                    r"dropbear\[(\d+)\]: .*?(?:Password|Pubkey) auth succeeded for "
                    r"'([^']+)' from ([^ ]+):(\d+)",
                    line,
                )
                if m:
                    auth[int(m.group(1))] = (
                        m.group(2), normalize_ip(m.group(3)), int(m.group(4))
                    )
        break
    return auth


def ws_ip_for(child_ts):
    """Real client IP for a ws target connection created at child_ts."""
    if not child_ts:
        return None
    since = "@%.6f" % max(0.0, child_ts / 1e6 - 2)
    until = "@%.6f" % (child_ts / 1e6 + 2)
    opened = []
    clients = []
    for ts, msg in journal_entries(unit="ws", since=since, until=until):
        if WS_OPEN_RE.search(msg):
            opened.append(ts)
        elif "client:" in msg:
            m = WS_CLIENT_RE.search(msg)
            if m:
                clients.append((ts, normalize_ip(m.group(1))))
    if not opened or not clients:
        return None
    # The target connection is opened at the same instant as the Dropbear
    # child.  Pick the nearest "opened" line, then the client line emitted
    # with it (the pair is usually <0.05 ms apart).
    ot = min(opened, key=lambda ts: abs(ts - child_ts))
    if abs(ot - child_ts) > OPEN_TOL_US:
        return None
    best = None
    best_delta = None
    for ct, ip in clients:
        # Found 524: the ws proxy usually logs "client:" just before
        # "opened", but live journald order can be reversed (observed
        # 2.2 ms after).  The old one-way check then left the session at
        # 127.0.0.1.  Match the nearest client line on either side within
        # the pair window; the next connection's lines are farther away.
        delta = abs(ot - ct)
        if delta > CLIENT_TOL_US:
            continue
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best = ip
    return best


def haproxy_entries(since_us, until_us):
    """Client IPs and accept timestamps from HAProxy's 777 TCP log."""
    entries = []
    seen = set()

    def add(line):
        m = HAPROXY_RE.search(line)
        if not m:
            return
        token = m.group(1)
        if token.startswith("[") and "]:" in token:
            host = token[1:].split("]:", 1)[0]
        else:
            try:
                host, _port = token.rsplit(":", 1)
            except ValueError:
                return
        host = normalize_ip(host)
        try:
            ipaddress.ip_address(host)
        except ValueError:
            return
        month = MONTHS.get(m.group(3))
        if not month:
            return
        try:
            ts = datetime.datetime(
                int(m.group(4)), month, int(m.group(2)),
                int(m.group(5)), int(m.group(6)), int(m.group(7)),
                int(m.group(8)) * 1000,
            ).timestamp()
        except Exception:
            return
        ts_us = int(ts * 1e6)
        if ts_us < since_us - HAPROXY_PAD_US or ts_us > until_us + HAPROXY_PAD_US:
            return
        # Keep the full client:port token in the dedup key. Two clients behind
        # the same NAT can connect in the same millisecond; deduping only on
        # (timestamp, IP) would drop one of their evidence lines.
        key = (ts_us, token)
        if key in seen:
            return
        seen.add(key)
        entries.append((ts_us, host))

    for path in HAPROXY_LOG_PATHS:
        try:
            fh = open(path, errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                add(line)
    since = "@%.6f" % max(0.0, (since_us - HAPROXY_PAD_US) / 1e6)
    until = "@%.6f" % ((until_us + HAPROXY_PAD_US) / 1e6)
    for _ts, msg in journal_entries(unit="haproxy", since=since, until=until):
        add(msg)
    entries.sort()
    return entries


def resolve_ws(sessions):
    for session in sessions:
        if session[1] == "127.0.0.1" and session[4]:
            real = ws_ip_for(session[4])
            if real:
                session[1] = real


def resolve_haproxy(sessions):
    """Match 777 sessions one-to-one to HAProxy accept log lines.

    The accept timestamp is always at or before the Dropbear child start
    (HAProxy must finish the TLS handshake and connect to the backend first).
    A small negative delta is tolerated for clock granularity.
    """
    pending = [s for s in sessions if s[1] == "127.0.0.1" and s[4]]
    if not pending:
        return
    entries = haproxy_entries(
        min(s[4] for s in pending), max(s[4] for s in pending)
    )
    if not entries:
        return
    used = set()
    for session in sorted(pending, key=lambda item: item[4]):
        best = None
        best_delta = None
        for i, (ts, _ip) in enumerate(entries):
            if i in used:
                continue
            delta = session[4] - ts
            if delta < -HAPROXY_SKEW_US or delta > HAPROXY_TOL_US:
                continue
            if best_delta is None or delta < best_delta:
                best = i
                best_delta = delta
        if best is not None:
            used.add(best)
            session[1] = entries[best][1]


def dropbear_sessions():
    log_auth = dropbear_auth_log()
    out = []
    for listener in listener_pids("dropbear"):
        for pid in children(listener):
            start = start_epoch(pid)
            if start is None:
                start = time.time() - 7 * 86400
            child, auth = auth_for_pid(pid, start)
            if not auth and pid in log_auth:
                user, ip, port = log_auth[pid]
                ts = int(start * 1e6)
                child = (ts, ip, port)
                auth = (ts, user, ip, port)
            if not auth:
                continue
            user, ip, _port = auth[1], auth[2], auth[3]
            # The process start is the child-connection time even when the
            # journal's "Child connection" line has aged out; using the auth
            # timestamp here would be minutes late for a slow password entry
            # and would break the ws/777 timestamp match.
            child_ts = child[0] if child else int(start * 1e6)
            out.append([user, ip, "Dropbear", pid, child_ts])
    return out


def openssh_sessions():
    log_auth = openssh_auth_log()
    out = []
    for listener in listener_pids("sshd"):
        for pid in children(listener):
            start = start_epoch(pid)
            if start is None:
                start = time.time() - 7 * 86400
            _child, auth = auth_for_pid(pid, start)
            if auth:
                user, ip = auth[1], auth[2]
            elif pid in log_auth:
                user, ip = log_auth[pid]
            else:
                continue
            out.append([user, ip, "Openssh", pid, None])
    return out


def main():
    sessions = dropbear_sessions() + openssh_sessions()
    resolve_ws(sessions)
    resolve_haproxy(sessions)
    seen = set()
    for user, ip, kind, pid, _ts in sorted(
        sessions, key=lambda s: (s[0], s[1], s[2], s[3])
    ):
        key = (user, ip, kind, pid)
        if key in seen:
            continue
        seen.add(key)
        print(f"{user}\t{ip}\t{kind}\t{pid}")


if __name__ == "__main__":
    main()
PY
