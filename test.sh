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
before_evidence=$(sha256sum "$HOME_ROOT/level6/evidence/scheduling-snapshot.txt" | awk '{print $1}')
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
after_evidence=$(sha256sum "$HOME_ROOT/level6/evidence/scheduling-snapshot.txt" | awk '{print $1}')
after_answer=$(sed -n '1p' "$ANSWER_DIR/level6")
[ "$before_case" = "$after_case" ]
[ "$before_evidence" = "$after_evidence" ]
[ "$before_answer" = "$after_answer" ]

HOME_ROOT="$HOME_ROOT" ANSWER_DIR="$ANSWER_DIR" sh "$INSTALL_ROOT/verify.sh"

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
    echo "Generator, variation, solver, and helper compilation tests passed."
else
    echo "Generator, variation, and solver tests passed (helper compilation skipped)."
fi
