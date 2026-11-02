#!/bin/bash
# Found 539: insert an Xray client without a template anchor object.
#
# The JSON configs use `#` comment lines as account markers.  Xray ignores
# those comments, but they are not strict JSON, so this helper edits the text
# directly instead of parsing the whole file.  It finds the inbound by
# protocol, walks to its clients array, and inserts the new client immediately
# before the closing `]`, adding the comma to the previous last client.
#
# Usage: xray-add-client <json-file> <vless|vmess|trojan> <user> <expiry> <id>

set -u

if [ "$#" -ne 5 ]; then
    echo "usage: xray-add-client <json-file> <vless|vmess|trojan> <user> <expiry> <id>" >&2
    exit 2
fi

file="$1"
proto="$2"
user="$3"
exp="$4"
uuid="$5"

case "$proto" in
    vless | vmess | trojan) ;;
    *)
        echo "xray-add-client: unsupported protocol: $proto" >&2
        exit 2
        ;;
esac

if ! [[ "$user" =~ ^[a-z0-9_]+$ ]]; then
    echo "xray-add-client: invalid username: $user" >&2
    exit 2
fi
if ! [[ "$uuid" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "xray-add-client: invalid id/password: $uuid" >&2
    exit 2
fi
if ! [[ "$exp" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "xray-add-client: invalid expiry: $exp" >&2
    exit 2
fi

[ -f "$file" ] || {
    echo "xray-add-client: no such file: $file" >&2
    exit 1
}
command -v python3 >/dev/null 2>&1 || {
    echo "xray-add-client: python3 is required" >&2
    exit 1
}

python3 - "$file" "$proto" "$user" "$exp" "$uuid" <<'PY'
import re
import sys
from pathlib import Path

path, proto, user, exp, uuid = sys.argv[1:6]
lines = Path(path).read_text().splitlines(keepends=True)
proto_re = re.compile(r'"protocol"\s*:\s*"' + re.escape(proto) + r'"')

start = None
for i, line in enumerate(lines):
    if proto_re.search(line):
        start = i
        break
if start is None:
    sys.exit(f"xray-add-client: {proto} inbound not found in {path}")

clients_start = None
for i in range(start, len(lines)):
    if '"clients"' in lines[i] and "[" in lines[i]:
        clients_start = i
        break
if clients_start is None:
    sys.exit(f"xray-add-client: {proto} clients array not found in {path}")

depth = 0
clients_end = None
for i in range(clients_start, len(lines)):
    depth += lines[i].count("[") - lines[i].count("]")
    if i > clients_start and depth == 0:
        clients_end = i
        break
if clients_end is None:
    sys.exit(f"xray-add-client: {proto} clients array is not closed in {path}")

last = clients_end - 1
while last > clients_start:
    stripped = lines[last].strip()
    if stripped and not stripped.startswith("#"):
        break
    last -= 1

if last > clients_start:
    current = lines[last].rstrip("\n")
    if current.strip().endswith("}") and not current.rstrip().endswith(","):
        lines[last] = current + ",\n"

key = "password" if proto == "trojan" else "id"
if proto == "vmess":
    body = f'{{"{key}": "{uuid}","alterId": 0,"email": "{user}","level": 0}}'
else:
    body = f'{{"{key}": "{uuid}","email": "{user}","level": 0}}'

lines[clients_end:clients_end] = [f"### {user} {exp}\n", body + "\n"]
Path(path).write_text("".join(lines))
PY
