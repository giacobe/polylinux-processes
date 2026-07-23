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
SKIP_OWNERSHIP=1
export USER_ID currentDate SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT CASE_ROOT SKIP_OWNERSHIP
mkdir -p "$CASE_ROOT" "$test_root/home"

n=1
while [ "$n" -le 10 ]; do
    levelnumber=$n
    levelToBuild="level$n"
    LEVEL_HOME="$test_root/home/$levelToBuild"
    levelPassword="${LEVEL_PASSWORD_ROOT}${n}"
    level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
        "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
    export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
    mkdir -p "$LEVEL_HOME"
    sh "$INSTALL_ROOT/level$n.sh"
    n=$((n + 1))
done

# Confirm deterministic reproduction for a representative case.
before=$(sha256sum "$CASE_ROOT/level6/case.conf" | awk '{print $1}')
sh "$INSTALL_ROOT/level6.sh"
after=$(sha256sum "$CASE_ROOT/level6/case.conf" | awk '{print $1}')
[ "$before" = "$after" ]

if [ "$compiled" = yes ]; then
    echo "Generator and helper compilation tests passed."
else
    echo "Generator tests passed (helper compilation skipped)."
fi
