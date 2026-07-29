#!/bin/sh
set -eu

cd "$(dirname "$0")"
CASE_ROOT=${CASE_ROOT:-/var/lib/process-lab/cases}
SUBMISSION_ROOT=${SUBMISSION_ROOT:-/home}
failures=0

n=1
while [ "$n" -le 10 ]; do
    case_file="$CASE_ROOT/level$n/case.conf"
    submission="$SUBMISSION_ROOT/level$n/submission-level$n.txt"
    if sh ./verify-submission.sh "$case_file" "$submission"; then
        :
    else
        failures=$((failures + 1))
    fi
    n=$((n + 1))
done

[ "$failures" -eq 0 ] || exit 1
echo "All live-state submissions passed."

