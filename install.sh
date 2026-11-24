#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
LAB_ID='process-lab'
LAB_TITLE='Processes and Job Control'
SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-systemPassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
currentDate=${CURRENT_DATE:-$(date +%Y-%m-%d)}
export INSTALL_ROOT LAB_ID LAB_TITLE SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT currentDate

. "$INSTALL_ROOT/resources.sh"
. "$INSTALL_ROOT/polylinux-common.sh"

NON_INTERACTIVE=0
NO_LOGIN=0
for arg in "$@"; do
    case "$arg" in
        --non-interactive) NON_INTERACTIVE=1 ;;
        --no-login) NO_LOGIN=1 ;;
        *) die "unknown option: $arg" ;;
    esac
done

if [ "$NON_INTERACTIVE" -eq 1 ]; then
    raw_user=${USER_ID:-student@example.edu}
else
    confirmation=n
    while [ "$confirmation" != y ]; do
        printf 'Enter your email address: '
        IFS= read -r raw_user
        normalized=$(normalize_email "$raw_user")
        validate_email "$normalized" || { echo 'That address is not valid.' >&2; continue; }
        printf 'The exercise will use %s. Is that correct? (y/n) ' "$normalized"
        IFS= read -r confirmation
    done
fi
USER_ID=$(normalize_email "$raw_user")
validate_email "$USER_ID" || die 'invalid email address after normalization'
validate_iso_date "$currentDate" || die 'CURRENT_DATE must be YYYY-MM-DD'
EXERCISE_CODE=$(exercise_code_from_date "$currentDate")
export USER_ID EXERCISE_CODE
select_theme
THEME_OFFSET=$THEME_INDEX
THEME_STEP=0
export THEME_OFFSET THEME_STEP

for cmd in adduser awk basename cat chmod chown cp cut date grep head id kill ln mkdir mkfifo mv nice passwd ps renice rm sed sha256sum sleep sort su tail tr wc; do command_required "$cmd"; done

mkdir -p /home /var/lib/process-lab/cases /usr/lib/process-lab /etc/profile.d
if [ -f "$INSTALL_ROOT/process-helper" ]; then
    cp "$INSTALL_ROOT/process-helper" /usr/lib/process-lab/process-helper
    chmod 755 /usr/lib/process-lab/process-helper
else
    die "prebuilt process-helper is missing from the exercise payload"
fi
smoke_dir="/run/process-lab-helper-smoke.$$"
mkdir -p "$smoke_dir"
/usr/lib/process-lab/process-helper worker "$smoke_dir" smoke smoke normal 1 receipt \
    >"$smoke_dir/output" 2>&1 &
smoke_pid=$!
sleep 1
if ! kill -0 "$smoke_pid" 2>/dev/null || ! grep -q '^smoke ' "$smoke_dir/registry" 2>/dev/null; then
    wait "$smoke_pid" 2>/dev/null || true
    die "process-helper failed its startup smoke test; see $smoke_dir/output"
fi
kill "$smoke_pid" 2>/dev/null || true
wait "$smoke_pid" 2>/dev/null || true
rm -rf "$smoke_dir"
cp "$INSTALL_ROOT/startlevel.sh" /usr/lib/process-lab/startlevel.sh
chmod 644 /usr/lib/process-lab/startlevel.sh
cp "$INSTALL_ROOT/monitor-level4.sh" /usr/lib/process-lab/monitor-level4.sh
chmod 755 /usr/lib/process-lab/monitor-level4.sh

cp "$INSTALL_ROOT/polylinux-colors.sh" /etc/profile.d/polylinux-colors.sh
chmod 644 /etc/profile.d/polylinux-colors.sh
cp "$INSTALL_ROOT/profile" /etc/profile
for helper in nextlevel prevlevel levelstatus cleanlevel; do
    cp "$INSTALL_ROOT/$helper" "/usr/bin/$helper"
    chmod 755 "/usr/bin/$helper"
done
cp "$INSTALL_ROOT/validate" /usr/bin/process-validate
chmod 755 /usr/bin/process-validate

. "$INSTALL_ROOT/polylinux-parallel-runtime.sh"
prepare_standard_accounts
echo "Exercise code: $EXERCISE_CODE"
start_standard_levels
