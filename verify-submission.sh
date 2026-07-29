#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "Usage: verify-submission.sh CASE.CONF SUBMISSION.txt" >&2
    exit 2
}
case_file=$1
submission=$2
[ -r "$case_file" ] || { echo "Unreadable case file: $case_file" >&2; exit 2; }
[ -r "$submission" ] || { echo "Unreadable submission: $submission" >&2; exit 2; }
. "$case_file"

tmp="${TMPDIR:-/tmp}/process-submission-verify.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

claimed=$(tail -n 1 "$submission" | sed -n 's/^SHA256|//p')
[ "${#claimed}" -eq 64 ] || { echo "FAIL: missing SHA256 line" >&2; exit 1; }
sed '$d' "$submission" > "$tmp"
actual=$(sha256sum "$tmp" | awk '{print $1}')
[ "$actual" = "$claimed" ] || { echo "FAIL: SHA256 mismatch" >&2; exit 1; }

field() { awk -F '|' -v key="$1" '$1==key {print $2; exit}' "$tmp"; }
process() { awk -F '|' -v role="$1" '$1=="PROCESS" && $2==role {print; exit}' "$tmp"; }
state() { process "$1" | awk -F '|' '{print $6}'; }
nice_value() { process "$1" | awk -F '|' '{print $7}'; }
alive() { [ "$(state "$1")" != X ] && process "$1" | grep -F -q '|token=match'; }
dead() { [ "$(state "$1")" = X ]; }
event_has() { grep -F -q "EVENT|$1" "$tmp"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(field LEARNER)" = "$LEARNER_ID" ] || fail "learner mismatch"
[ "$(field DATE)" = "$EXERCISE_DATE" ] || fail "date mismatch"
[ "$(field LEVEL)" = "$LEVEL" ] || fail "level mismatch"
[ "$(field THEME)" = "$THEME" ] || fail "theme mismatch"
[ "$(field LAUNCH)" = "$TOKEN" ] || fail "launch mismatch"
[ "$(sed -n '1p' "$tmp")" = "POLYLINUX-PROCESS-SNAPSHOT|1" ] ||
    fail "snapshot header mismatch"
[ "$(tail -n 1 "$tmp")" = "END|POLYLINUX-PROCESS-SNAPSHOT" ] ||
    fail "snapshot footer mismatch"

case "$LEVEL" in
    1)
        row=$(process "$TARGET")
        [ -n "$row" ] || fail "target process missing"
        alive "$TARGET" || fail "target process not alive"
        expected=$(printf '%s\n' "$row" | awk -F '|' '{print $3 "|" $4 "|" $6}')
        assertion=$(sed -n 's/^ASSERTION|//p' "$tmp")
        [ "$assertion" = "$expected" ] || fail "PID/PPID/state assertion mismatch"
        ;;
    2)
        dead "$TARGET" || fail "target still alive"
        grep -F -q "RECEIPT|$RECEIPT|role=$TARGET " "$tmp" ||
            fail "graceful shutdown receipt missing"
        for role in $DISTRACTOR_ROLES; do alive "$role" || fail "$role was not preserved"; done
        ;;
    3)
        dead "$TARGET" || fail "target still alive"
        case "$IGNORED_SIGNAL" in TERM) ignored=15 ;; INT) ignored=2 ;; HUP) ignored=1 ;; esac
        event_has "$TARGET " || fail "target event missing"
        grep -F -q "EVENT|$TARGET " "$tmp" || fail "target event missing"
        grep -F "EVENT|$TARGET " "$tmp" | grep -F -q "ignored=$ignored" ||
            fail "ignored signal was not observed"
        for role in $DISTRACTOR_ROLES; do alive "$role" || fail "$role was not preserved"; done
        ;;
    4)
        alive "$TARGET" || fail "heartbeat worker not alive"
        [ "$(state "$TARGET")" != T ] || fail "heartbeat worker still stopped"
        grep -F -q "EVENT|$TARGET " "$tmp" || fail "continue event missing"
        grep -F "EVENT|$TARGET " "$tmp" | grep -F -q "signal=CONT" ||
            fail "continue event missing"
        for role in $DISTRACTOR_ROLES; do alive "$role" || fail "$role was not preserved"; done
        ;;
    5)
        [ "$(state "$JOB_A")" = T ] || fail "$JOB_A is not stopped"
        alive "$JOB_B" || fail "$JOB_B is not running"
        [ "$(state "$JOB_B")" != T ] || fail "$JOB_B is stopped"
        ;;
    6)
        alive "$TARGET" || fail "CPU worker not alive"
        [ "$(nice_value "$TARGET")" = "$REQUIRED_NICE" ] ||
            fail "CPU worker nice value mismatch"
        for role in $DISTRACTOR_ROLES; do alive "$role" || fail "$role was not preserved"; done
        ;;
    7)
        awk -F '|' -v role="$TARGET_BRANCH" \
            '$1=="PROCESS" && ($2==role || index($2,role"-child")==1) && $6!="X" {bad=1} END {exit bad}' "$tmp" ||
            fail "target branch remains alive"
        awk -F '|' -v role="$PROTECTED_BRANCH" \
            '$1=="PROCESS" && ($2==role || index($2,role"-child")==1) && $6!="X" && $9=="token=match" {ok++}
             END {exit !(ok>0)}' "$tmp" || fail "protected branch is not alive"
        ;;
    8)
        awk -F '|' -v role="$TARGET_GROUP" \
            '$1=="PROCESS" && index($2,role"-member")==1 && $6!="X" {bad=1} END {exit bad}' "$tmp" ||
            fail "target group remains alive"
        awk -F '|' -v role="$PROTECTED_GROUP" \
            '$1=="PROCESS" && index($2,role"-member")==1 && $6!="X" && $9=="token=match" {ok++}
             END {exit !(ok>0)}' "$tmp" || fail "protected group is not alive"
        ;;
    9)
        dead "$ZOMBIE" || fail "zombie was not reaped"
        alive "$PARENT" || fail "zombie parent is not alive"
        grep -F "EVENT|$PARENT " "$tmp" | grep -F -q "reaped=" ||
            fail "reap event missing"
        ;;
    10)
        alive "$HOG" || fail "CPU worker not alive"
        [ "$(nice_value "$HOG")" = "$REQUIRED_NICE" ] || fail "CPU worker nice mismatch"
        alive "$PAUSED" || fail "paused worker not alive"
        [ "$(state "$PAUSED")" != T ] || fail "paused worker still stopped"
        dead "$STUBBORN" || fail "stubborn worker still alive"
        alive "$PROTECTED" || fail "protected worker not alive"
        grep -F "EVENT|$STUBBORN " "$tmp" | grep -F -q "ignored=15" ||
            fail "TERM test for stubborn worker missing"
        awk -F '|' -v role="$TARGET_GROUP" \
            '$1=="PROCESS" && index($2,role"-member")==1 && $6!="X" {bad=1} END {exit bad}' "$tmp" ||
            fail "incident group remains alive"
        ;;
    *) fail "unsupported level $LEVEL" ;;
esac

echo "PASS|level=$LEVEL|sha256=$actual"
