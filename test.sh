#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
export INSTALL_ROOT
. "$INSTALL_ROOT/resources.sh"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/polylinux-processes.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

compiled=yes
if [ "${SKIP_COMPILE:-0}" != 1 ]; then
    cc -O2 -Wall -Wextra -Werror -o "$test_root/process-helper" process-helper.c
else
    compiled=no
fi

USER_ID=${USER_ID:-student@example.edu}
currentDate=${CURRENT_DATE:-2026-07-23}
SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-exercisePassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
CASE_ROOT="$test_root/cases"
ANSWER_DIR="$test_root/answers"
HOME_ROOT="$test_root/home"
SKIP_OWNERSHIP=1
export USER_ID currentDate SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT CASE_ROOT ANSWER_DIR HOME_ROOT SKIP_OWNERSHIP
mkdir -p "$CASE_ROOT" "$ANSWER_DIR" "$HOME_ROOT"

n=1
while [ "$n" -le 10 ]; do
    levelnumber=$n
    levelToBuild="level$n"
    LEVEL_HOME="$HOME_ROOT/$levelToBuild"
    levelPassword="${LEVEL_PASSWORD_ROOT}${n}"
    level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
        "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
    export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
    mkdir -p "$LEVEL_HOME"
    sh "$INSTALL_ROOT/level$n.sh"
    n=$((n + 1))
done

# Confirm deterministic reproduction for a representative case and answer.
before_case=$(sha256sum "$CASE_ROOT/level6/case.conf" | awk '{print $1}')
before_answer=$(sed -n '1p' "$ANSWER_DIR/level6")
levelnumber=6
levelToBuild=level6
LEVEL_HOME="$HOME_ROOT/level6"
levelPassword="${LEVEL_PASSWORD_ROOT}6"
level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
    "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
sh "$INSTALL_ROOT/level6.sh"
after_case=$(sha256sum "$CASE_ROOT/level6/case.conf" | awk '{print $1}')
after_answer=$(sed -n '1p' "$ANSWER_DIR/level6")
[ "$before_case" = "$after_case" ]
[ "$before_answer" = "$after_answer" ]

# Learners must not receive the previous precomputed evidence shortcut.
[ ! -d "$HOME_ROOT/level1/evidence" ]
[ ! -d "$HOME_ROOT/level10/evidence" ]
if grep -R -E 'role=(decoy|peer|worker)-[0-9]+' "$CASE_ROOT" "$HOME_ROOT" >/dev/null 2>&1; then
    echo "obvious numbered distractor name found" >&2
    exit 1
fi

# Exercise the submission integrity and semantic verifier with a synthetic
# Level 1 live-state snapshot.
. "$CASE_ROOT/level1/case.conf"
submission="$test_root/submission-level1.txt"
blob="$test_root/submission-level1.blob"
{
    echo "POLYLINUX-PROCESS-SNAPSHOT|1"
    printf 'LEARNER|%s\n' "$LEARNER_ID"
    printf 'DATE|%s\n' "$EXERCISE_DATE"
    printf 'LEVEL|%s\n' "$LEVEL"
    printf 'THEME|%s\n' "$THEME"
    printf 'LAUNCH|%s\n' "$TOKEN"
    echo "ASSERTION|321|100|S"
    printf 'PROCESS|%s|321|100|321|S|0|%s|token=match\n' "$TARGET" "$TARGET"
    echo "END|POLYLINUX-PROCESS-SNAPSHOT"
} > "$blob"
{
    cat "$blob"
    printf 'SHA256|%s\n' "$(sha256sum "$blob" | awk '{print $1}')"
} > "$submission"
sh "$INSTALL_ROOT/verify-submission.sh" "$CASE_ROOT/level1/case.conf" "$submission" >/dev/null
sed 's/ASSERTION|321|100|S/ASSERTION|999|100|S/' "$submission" > "$submission.tampered"
if sh "$INSTALL_ROOT/verify-submission.sh" "$CASE_ROOT/level1/case.conf" \
    "$submission.tampered" >/dev/null 2>&1; then
    echo "tampered submission unexpectedly passed" >&2
    exit 1
fi

original_level1=$(sed -n '1p' "$ANSWER_DIR/level1")
variation_root="$test_root/variation"
USER_ID=changed.student@example.edu
CASE_ROOT="$variation_root/cases"
ANSWER_DIR="$variation_root/answers"
HOME_ROOT="$variation_root/home"
levelnumber=1
levelToBuild=level1
LEVEL_HOME="$HOME_ROOT/level1"
levelPassword="${LEVEL_PASSWORD_ROOT}1"
level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
    "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
export USER_ID CASE_ROOT ANSWER_DIR HOME_ROOT levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
mkdir -p "$CASE_ROOT" "$ANSWER_DIR" "$LEVEL_HOME"
sh "$INSTALL_ROOT/level1.sh"
changed_level1=$(sed -n '1p' "$ANSWER_DIR/level1")
[ "$original_level1" != "$changed_level1" ]

if [ "$compiled" = yes ]; then
    echo "Generator, variation, snapshot verifier, tamper detection, and helper compilation tests passed."
else
    echo "Generator, variation, snapshot verifier, and tamper detection tests passed (helper compilation skipped)."
fi
