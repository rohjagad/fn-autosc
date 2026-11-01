#!/bin/bash
#
# Verify the individual-file payload before committing (Found 513).
#
# For each menu/<edition>.manifest line:
#   script <name> -> <edition>/<name>.sh must exist and pass bash -n
#   web    <name> -> website/<name>.sh must exist and pass bash -n
#   bin    <name> -> bin/<edition>/<name> must exist, be executable and ELF
#
# Also checks for duplicate manifest names and orphan binaries that are not
# listed in the manifest.

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
fail=0

for edition in full lite; do
    manifest="menu/${edition}.manifest"
    if [ ! -s "$manifest" ]; then
        echo "MISSING $manifest"
        fail=1
        continue
    fi

    seen=" "
    total=0
    while IFS= read -r line || [ -n "${line:-}" ]; do
        line="${line%$'\r'}"
        case "$line" in
            '' | \#*) continue ;;
        esac
        read -r kind name extra <<< "$line"
        if [ -z "${name:-}" ] || [ -n "${extra:-}" ]; then
            echo "BAD LINE $manifest: $line"
            fail=1
            continue
        fi
        case "$seen" in
            *" $name "*)
                echo "DUPLICATE $manifest: $name"
                fail=1
                continue
                ;;
        esac
        seen="$seen$name "
        total=$((total + 1))
        case "$kind" in
            script)
                src="${edition}/${name}.sh"
                if [ ! -f "$src" ]; then
                    echo "MISSING $src"
                    fail=1
                elif ! bash -n "$src"; then
                    echo "SYNTAX $src"
                    fail=1
                fi
                ;;
            web)
                src="website/${name}.sh"
                if [ ! -f "$src" ]; then
                    echo "MISSING $src"
                    fail=1
                elif ! bash -n "$src"; then
                    echo "SYNTAX $src"
                    fail=1
                fi
                ;;
            bin)
                src="bin/${edition}/${name}"
                if [ ! -f "$src" ]; then
                    echo "MISSING $src"
                    fail=1
                    continue
                fi
                [ -x "$src" ] || { echo "NOT EXEC $src"; fail=1; }
                magic=$(od -An -tx1 -N4 "$src" 2>/dev/null | tr -d ' \n')
                [ "$magic" = "7f454c46" ] || { echo "NOT ELF $src"; fail=1; }
                ;;
            *)
                echo "BAD KIND $manifest: $kind"
                fail=1
                ;;
        esac
    done < "$manifest"

    if [ -d "bin/$edition" ]; then
        for bin in "bin/$edition"/*; do
            [ -e "$bin" ] || continue
            name=$(basename "$bin")
            case "$seen" in
                *" $name "*) ;;
                *) echo "ORPHAN $bin"; fail=1 ;;
            esac
        done
    fi
    if [ -d "$edition" ]; then
        for src in "$edition"/*.sh; do
            [ -e "$src" ] || continue
            name=$(basename "$src" .sh)
            case "$seen" in
                *" $name "*) ;;
                *) echo "ORPHAN $src"; fail=1 ;;
            esac
        done
    fi
    echo "${edition}: ${total} manifest entries checked"
done

if [ "$fail" -eq 0 ]; then
    echo "payload verification OK"
else
    echo "payload verification FAILED" >&2
fi
exit "$fail"
