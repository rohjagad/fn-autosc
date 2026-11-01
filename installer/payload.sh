#!/bin/bash
#
# payload.sh - install the panel payload one file at a time.
#
# Found 513: the old installers downloaded menu/full.zip or menu/lite.zip
# (~56 MB / ~36 MB), unpacked it into /usr/bin and discarded the archive.
# Every script change meant rebuilding, re-uploading and re-downloading the
# whole archive.  This helper reads menu/<edition>.manifest instead:
#
#     script  <name>   ->  <edition>/<name>.sh
#     bin     <name>   ->  bin/<edition>/<name>
#
# All files are downloaded to a staging directory and verified before any
# destination file is replaced.  A failed/truncated download aborts the
# install and leaves /usr/bin untouched.
#
# Usage: payload.sh full|lite
# Env:   FN_HOSTING  repository raw base (default: GitHub main)
#        FN_DESTDIR  destination directory (default: /usr/bin; for tests)

set -u

edition="${1:-}"
case "$edition" in
    full | lite) ;;
    *)
        echo "payload.sh: usage: payload.sh full|lite" >&2
        exit 2
        ;;
esac

hosting="${FN_HOSTING:-https://raw.githubusercontent.com/rohjagad/fn-autosc/main}"
dest="${FN_DESTDIR:-/usr/bin}"
manifest_url="${hosting}/menu/${edition}.manifest"
stage=$(mktemp -d "${TMPDIR:-/var/tmp}/fn-payload.XXXXXX") || {
    echo "payload: cannot create staging directory" >&2
    exit 1
}
trap 'rm -rf "$stage"' EXIT

fetch() {
    local url="$1" out="$2" limit="$3"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time "$limit" --retry 3 --retry-delay 5 "$url" -o "$out"
    else
        wget -q --timeout="$limit" --tries=3 -O "$out" "$url"
    fi
}

fail() {
    echo "payload: FAILED: $*" >&2
    echo "payload: no existing file in $dest was replaced." >&2
    exit 1
}

echo "Downloading ${edition} payload manifest..."
fetch "$manifest_url" "$stage/manifest" 60 || fail "cannot download $manifest_url"
[ -s "$stage/manifest" ] || fail "empty manifest $manifest_url"

total=$(grep -cE '^(script|bin)[[:space:]]' "$stage/manifest" 2>/dev/null || true)
scripts=$(grep -cE '^script[[:space:]]' "$stage/manifest" 2>/dev/null || true)
bins=$(grep -cE '^bin[[:space:]]' "$stage/manifest" 2>/dev/null || true)
[ "$total" -gt 0 ] || fail "manifest has no entries"
echo "Payload: ${total} files (${scripts} scripts, ${bins} binaries)"

mkdir -p "$dest" || fail "cannot create $dest"
[ -w "$dest" ] || fail "$dest is not writable"

i=0
while IFS= read -r line || [ -n "${line:-}" ]; do
    line="${line%$'\r'}"
    case "$line" in
        '' | \#*) continue ;;
    esac
    read -r kind name extra <<< "$line"
    [ -z "${extra:-}" ] || fail "bad manifest line: $line"
    [ -n "${name:-}" ] || fail "bad manifest line: missing name: $line"
    if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
        fail "unsafe payload name: $name"
    fi
    case "$kind" in
        script)
            url="${hosting}/${edition}/${name}.sh"
            limit=120
            ;;
        bin)
            url="${hosting}/bin/${edition}/${name}"
            limit=600
            ;;
        *)
            fail "unknown payload kind: $kind"
            ;;
    esac
    i=$((i + 1))
    printf '  [%3d/%3d] %-6s %s\n' "$i" "$total" "$kind" "$name"
    fetch "$url" "$stage/$name" "$limit" || fail "cannot download $url"
    [ -s "$stage/$name" ] || fail "empty download $url"
    if [ "$kind" = "script" ]; then
        bash -n "$stage/$name" || fail "syntax error in $url"
    else
        magic=$(od -An -tx1 -N4 "$stage/$name" 2>/dev/null | tr -d ' \n')
        [ "$magic" = "7f454c46" ] || fail "not an ELF binary: $url"
    fi
done < "$stage/manifest"

[ "$i" -eq "$total" ] || fail "manifest count changed during download"

# Everything is downloaded and verified; replace the destination files.
while IFS= read -r line || [ -n "${line:-}" ]; do
    line="${line%$'\r'}"
    case "$line" in
        '' | \#*) continue ;;
    esac
    read -r kind name extra <<< "$line"
    install -m 0755 "$stage/$name" "$dest/$name" || fail "cannot install $dest/$name"
done < "$stage/manifest"

echo "Payload installed: ${total} files in ${dest}."
