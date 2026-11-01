#!/bin/bash
#
# Build the standalone payload binaries (Found 513).
#
# The installer and updater download individual files from bin/<edition>/;
# there is no menu zip to repack.  After changing a .go source, run this
# script, commit the changed binary, then run tools/verify-payload.sh.
#
# Output: bin/full/<name> and bin/lite/<name>, mode 0755, Linux amd64.
# The panel targets amd64; override GOARCH only if you know the fleet uses
# another architecture.

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

command -v go >/dev/null 2>&1 || {
    echo "build-binaries: go compiler not found" >&2
    exit 1
}

for edition in full lite; do
    mkdir -p "bin/$edition"
    for src in "$edition"/*.go; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .go)
        printf '  build %s/%s\n' "$edition" "$name"
        CGO_ENABLED=0 GOOS=linux GOARCH="${GOARCH:-amd64}" \
            go build -trimpath -ldflags="-s -w" -o "bin/$edition/$name" "$src"
        chmod 0755 "bin/$edition/$name"
        magic=$(od -An -tx1 -N4 "bin/$edition/$name" | tr -d ' \n')
        [ "$magic" = "7f454c46" ] || {
            echo "build-binaries: not an ELF: bin/$edition/$name" >&2
            exit 1
        }
    done
done

echo "binaries rebuilt; run tools/verify-payload.sh next"
