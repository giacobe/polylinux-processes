# This file is sourced by the startlevel shell function in /etc/profile.
_pl_level=${USER#level}
case "$_pl_level" in 1|2|3|4|5|6|7|8|9|10) ;; *) echo "Not in a level account."; return 1 ;; esac
_pl_case="/var/lib/process-lab/cases/level$_pl_level/case.conf"
_pl_run="$HOME/runtime"

if [ ! -r "$_pl_case" ]; then echo "Case configuration is missing."; return 1; fi

if [ -f "$_pl_run/registry" ]; then
    while read -r _pl_label _pl_pid _pl_ppid _pl_pgid; do
        case "$_pl_pid" in *[!0-9]*|'') ;; *) kill "$_pl_pid" 2>/dev/null || true ;; esac
    done < "$_pl_run/registry"
    sleep 1
    while read -r _pl_label _pl_pid _pl_ppid _pl_pgid; do
        case "$_pl_pid" in *[!0-9]*|'') ;; *) kill -KILL "$_pl_pid" 2>/dev/null || true ;; esac
    done < "$_pl_run/registry"
fi
rm -rf "$_pl_run"
mkdir -p "$_pl_run"
cp "$_pl_case" "$_pl_run/case.conf"
. "$_pl_run/case.conf"
_pl_helper=/usr/lib/process-lab/process-helper

_pl_worker() {
    "$_pl_helper" worker "$_pl_run" "$1" "${5:-$TOKEN}" "$2" "${3:-1}" "${4:-receipt}" \
        >>"$_pl_run/output" 2>&1 &
}

_pl_hidden_worker() {
    "$_pl_helper" worker "$_pl_run" "$1" "$TOKEN" - 1 receipt \
        >>"$_pl_run/output" 2>&1 <<EOF &
$2
EOF
}

_pl_watched_worker() (
    exec 3>>"$_pl_run/events"
    "$_pl_helper" worker "$_pl_run" "$1" "$TOKEN" - 1 receipt \
        >>"$_pl_run/output" 2>&1 <<EOF &
$2
EOF
    _pl_child=$!
    wait "$_pl_child"
    _pl_exit=$?
    printf '%s exit=%s\n' "$1" "$_pl_exit" >&3
)

case "$LEVEL" in
    1)
        for _pl_entry in $LEVEL1_ROSTER; do
            _pl_label=${_pl_entry%%:*}
            _pl_decoy_token=${_pl_entry#*:}
            _pl_worker "$_pl_label" normal 1 receipt "$_pl_decoy_token"
        done
        ;;
    2)
        for _pl_entry in $LEVEL2_ROSTER; do
            _pl_label=${_pl_entry%%:*}
            _pl_decoy_token=${_pl_entry#*:}
            _pl_worker "$_pl_label" graceful 1 "$RECEIPT" "$_pl_decoy_token"
        done
        ;;
    3)
        case "$IGNORED_SIGNAL" in TERM) _pl_mode=ignore-term ;; INT) _pl_mode=ignore-int ;; *) _pl_mode=ignore-hup ;; esac
        _pl_watched_worker "$TARGET" "$_pl_mode" &
        for _pl_label in $DISTRACTOR_ROLES; do _pl_hidden_worker "$_pl_label" normal; done
        ;;
    4)
        _pl_worker "$TARGET" heartbeat "$INTERVAL"
        for _pl_label in $DISTRACTOR_ROLES; do _pl_worker "$_pl_label" normal; done
        /usr/lib/process-lab/monitor-level4.sh "$_pl_run" "$TARGET" >>"$_pl_run/output" 2>&1 &
        ;;
    5)
        _pl_worker "$JOB_A" normal
        _pl_worker "$JOB_B" normal
        ;;
    6)
        _pl_worker "$TARGET" cpu
        for _pl_label in $DISTRACTOR_ROLES; do _pl_worker "$_pl_label" normal; done
        ;;
    7)
        "$_pl_helper" tree "$_pl_run" "$PARENT" "$TARGET_BRANCH" "$PROTECTED_BRANCH" "$CHILDREN" "$TOKEN" >>"$_pl_run/output" 2>&1 &
        ;;
    8)
        "$_pl_helper" groups "$_pl_run" "$TARGET_GROUP" "$PROTECTED_GROUP" "$STAGES" "$TOKEN" >>"$_pl_run/output" 2>&1 &
        ;;
    9)
        "$_pl_helper" zombie "$_pl_run" "$PARENT" "$ZOMBIE" "$CONTROL_SIGNAL" "$TOKEN" >>"$_pl_run/output" 2>&1 &
        ;;
    10)
        _pl_hidden_worker "$HOG" cpu
        _pl_hidden_worker "$PAUSED" normal
        _pl_hidden_worker "$STUBBORN" ignore-term
        _pl_hidden_worker "$PROTECTED" normal
        "$_pl_helper" groups "$_pl_run" "$TARGET_GROUP" "protected-group" 3 "$TOKEN" >>"$_pl_run/output" 2>&1 &
        sleep 1
        _pl_pid=$(awk -v n="$PAUSED" '$1==n {print $2; exit}' "$_pl_run/registry")
        kill -STOP "$_pl_pid"
        ;;
esac
sleep 1
echo "Level $LEVEL processes started. Inspect them with ps -ww -o pid,ppid,pgid,stat,ni,comm,args."
unset _pl_level _pl_case _pl_run _pl_helper _pl_i _pl_entry _pl_label _pl_decoy_token _pl_pid _pl_ppid _pl_pgid _pl_mode
