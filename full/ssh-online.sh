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
import os
import re
import subprocess
import time

AUTH_RE = re.compile(
    r"(?:Password|Pubkey) auth succeeded for '([^']+)' from ([^ ]+):(\d+)"
)
SSH_AUTH_RE = re.compile(
    r"Accepted (?:password|publickey) for ([^ ]+) from ([^ ]+) port (\d+)"
)
CHILD_RE = re.compile(r"Child connection from ([^ ]+):(\d+)")
WS_CLIENT_RE = re.compile(r"client:\s*([^,]+)")
WS_OPEN_RE = re.compile(r"opened .*127\.0\.0\.1:109")

OPEN_TOL_US = 50_000
CLIENT_TOL_US = 50_000
AUTH_WINDOW = 600


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
            child = (ts, m.group(1), int(m.group(2)))
        m = AUTH_RE.search(msg)
        if m:
            auth = (ts, m.group(1), m.group(2), int(m.group(3)))
        m = SSH_AUTH_RE.search(msg)
        if m:
            auth = (ts, m.group(1), m.group(2), int(m.group(3)))
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
                    r"sshd(?:-session)?\[(\d+)\]: Accepted (?:password|publickey) for "
                    r"([^ ]+) from ([^ ]+) port (\d+)",
                    line,
                )
                if m:
                    auth[int(m.group(1))] = (m.group(2), m.group(3))
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
                    auth[int(m.group(1))] = (m.group(2), m.group(3), int(m.group(4)))
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
                clients.append((ts, m.group(1).strip()))
    if not opened or not clients:
        return None
    # The target connection is opened at the same instant as the Dropbear
    # child.  Pick the nearest "opened" line, then the client line emitted
    # with it (the pair is usually <0.05 ms apart).
    ot = min(opened, key=lambda ts: abs(ts - child_ts))
    if abs(ot - child_ts) > OPEN_TOL_US:
        return None
    best = None
    best_key = None
    for ct, ip in clients:
        delta = abs(ct - ot)
        if delta > CLIENT_TOL_US:
            continue
        key = (delta, 0 if ct <= ot else 1)
        if best_key is None or key < best_key:
            best_key = key
            best = ip
    return best


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
            child_ts = child[0] if child else auth[0]
            if ip == "127.0.0.1":
                real = ws_ip_for(child_ts)
                if real:
                    ip = real
            out.append((user, ip, "Dropbear", pid))
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
            out.append((user, ip, "Openssh", pid))
    return out


def main():
    sessions = dropbear_sessions() + openssh_sessions()
    seen = set()
    for user, ip, kind, pid in sorted(sessions):
        key = (user, ip, kind, pid)
        if key in seen:
            continue
        seen.add(key)
        print(f"{user}\t{ip}\t{kind}\t{pid}")


if __name__ == "__main__":
    main()
PY
