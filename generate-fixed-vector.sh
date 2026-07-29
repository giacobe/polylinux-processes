#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
export INSTALL_ROOT
. "$INSTALL_ROOT/resources.sh"

[ "$#" -eq 1 ] || {
    echo "Usage: $0 OUTPUT_ROOT" >&2
    exit 2
}

OUTPUT_ROOT=$1
USER_ID=${USER_ID:-student@example.edu}
currentDate=${CURRENT_DATE:-2026-07-23}
SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-exercisePassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
CASE_ROOT="$OUTPUT_ROOT/cases"
ANSWER_DIR="$OUTPUT_ROOT/answers"
HOME_ROOT="$OUTPUT_ROOT/home"
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

HOME_ROOT="$HOME_ROOT" ANSWER_DIR="$ANSWER_DIR" sh "$INSTALL_ROOT/verify.sh"
{
    echo "email=$USER_ID"
    echo "date=$currentDate"
    echo "exercise_password=$SYSTEM_PASSWORD"
    n=1
    while [ "$n" -le 10 ]; do
        printf 'level%d=%s\n' "$n" "$(sed -n '1p' "$ANSWER_DIR/level$n")"
        n=$((n + 1))
    done
} > "$OUTPUT_ROOT/fixed-vector.txt"
