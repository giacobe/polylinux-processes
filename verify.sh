#!/bin/sh
set -eu

CASE_ROOT=${CASE_ROOT:-/var/lib/process-lab/cases}
failures=0

fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

[ -x /usr/lib/process-lab/process-helper ] || fail "process helper is not installed"

n=1
while [ "$n" -le 10 ]; do
    case_file="$CASE_ROOT/level$n/case.conf"
    [ -r "$case_file" ] || { fail "level$n case.conf is missing"; n=$((n+1)); continue; }
    level=$(sed -n 's/^LEVEL=//p' "$case_file")
    theme=$(sed -n 's/^THEME=//p' "$case_file")
    token=$(sed -n 's/^TOKEN=//p' "$case_file")
    [ "$level" = "$n" ] || fail "level$n has incorrect LEVEL"
    [ -n "$theme" ] || fail "level$n has no theme"
    [ "${#token}" -eq 10 ] || fail "level$n has malformed token"
    keys=$(cut -d= -f1 "$case_file" | sort | uniq -d)
    [ -z "$keys" ] || fail "level$n has duplicate configuration keys: $keys"
    echo "level$n: generated case OK"
    n=$((n + 1))
done

[ "$failures" -eq 0 ] || exit 1
echo "All generated cases passed structural verification."
