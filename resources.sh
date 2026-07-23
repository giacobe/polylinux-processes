#!/bin/sh

die() { echo "ERROR: $*" >&2; exit 1; }
command_required() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

derive_hex() {
    printf '%s:%s' "$level_HASH" "$1" | sha256sum | awk '{print $1}'
}

hex_byte() {
    _hex=$1 _index=$2
    _start=$((_index * 2 + 1))
    _pair=$(printf '%s' "$_hex" | cut -c "$_start-$((_start + 1))")
    printf '%d\n' "$((0x$_pair))"
}

range_from_byte() { printf '%d\n' "$(($2 + $1 % ($3 - $2 + 1)))"; }

pick_from_words() {
    _words=$1 _byte=$2
    set -- $_words
    _wanted=$((_byte % $# + 1))
    eval "printf '%s\n' \"\${$_wanted}\""
}

hex_fragment() { derive_hex "$1" | cut -c "1-$2"; }

theme_field() {
    case "$1:$2" in
        0:name) echo observatory ;;
        0:roles) echo "star-tracker image-stacker weather-sampler catalog-uploader orbit-monitor archive-writer" ;;
        1:name) echo greenhouse ;;
        1:roles) echo "soil-reader pump-controller humidity-exporter climate-monitor harvest-logger valve-worker" ;;
        2:name) echo research-vessel ;;
        2:roles) echo "sonar-reader route-recorder telemetry-uploader depth-monitor sample-indexer deck-sensor" ;;
        3:name) echo print-farm ;;
        3:roles) echo "job-router layer-renderer printer-monitor spool-writer material-reader queue-worker" ;;
        4:name) echo media-archive ;;
        4:roles) echo "catalog-scanner thumbnail-worker metadata-writer ingest-monitor index-builder checksum-reader" ;;
        *) die "unknown theme field $1:$2" ;;
    esac
}

level_begin() {
    LEVEL_DIR="${CASE_ROOT:-/var/lib/process-lab/cases}/$levelToBuild"
    rm -rf "$LEVEL_DIR"
    mkdir -p "$LEVEL_DIR"
    theme_index=$(( $(hex_byte "$(derive_hex theme)" 0) % 5 ))
    THEME=$(theme_field "$theme_index" name)
    ROLES=$(theme_field "$theme_index" roles)
    TOKEN=$(hex_fragment identity 10)
    printf 'LEVEL=%s\nTHEME=%s\nTOKEN=%s\n' "$levelnumber" "$THEME" "$TOKEN" > "$LEVEL_DIR/case.conf"
}

conf() { printf '%s=%s\n' "$1" "$2" >> "$LEVEL_DIR/case.conf"; }

role_at() {
    _offset=$1
    _h=$(derive_hex "role-$_offset")
    pick_from_words "$ROLES" "$(hex_byte "$_h" 0)"
}

role_from_index() {
    _index=$1
    set -- $ROLES
    _wanted=$((_index % $# + 1))
    eval "printf '%s\n' \"\${$_wanted}\""
}

write_level_readme() {
    {
        echo "* Exercise date : $currentDate"
        echo "* Learner       : $USER_ID"
        echo "* Theme         : $THEME"
        echo "************************************************************************"
        printf '%s\n' "$1"
        echo
        echo "Run 'startlevel' to create or reset this level's processes."
        echo "Run 'checklevel' after completing the requested actions."
        echo "Run 'levelstatus' for the current process identifiers and launch status."
    } > "$LEVEL_HOME/README.txt"
}

level_finish() {
    cp "$LEVEL_DIR/case.conf" "$LEVEL_HOME/case.conf"
    chmod 644 "$LEVEL_HOME/README.txt" "$LEVEL_HOME/case.conf"
    if [ "${SKIP_OWNERSHIP:-0}" != 1 ]; then
        chown -R "$levelToBuild:$levelToBuild" "$LEVEL_HOME"
        chown -R root:root "$LEVEL_DIR"
        chmod 700 "$LEVEL_HOME"
        chmod 755 "$LEVEL_DIR"
        chmod 644 "$LEVEL_DIR/case.conf"
    fi
}

build_level() {
    n=$1
    level_begin
    case "$n" in
        1)
            target=$(role_at 0); conf TARGET "$target"
            conf DISTRACTORS "$((4 + $(hex_byte "$(derive_hex count)" 0) % 4))"
            conf REQUIRED_FIELDS "pid|ppid|state"
            write_level_readme "PROCESS ROLL CALL
Locate the process whose command contains role=$target and token=$TOKEN.
Submit its live PID, PPID, and one-letter process state:
    checklevel PID|PPID|STATE
Useful commands: ps, grep."
            ;;
        2)
            target=$(role_at 1); receipt="shutdown-$(hex_fragment receipt 6).log"
            conf TARGET "$target"; conf RECEIPT "$receipt"; conf DISTRACTORS 4
            write_level_readme "GRACEFUL SHUTDOWN
The $target worker must be shut down cleanly. Identify it from its role and
token=$TOKEN, then send the normal termination signal. Do not stop its peers.
A correct shutdown creates runtime/$receipt.
Useful commands: ps, kill."
            ;;
        3)
            target=$(role_at 2)
            variant=$(( $(hex_byte "$(derive_hex behavior)" 0) % 3 ))
            case "$variant" in
                0) ignored=TERM; required=KILL ;;
                1) ignored=INT; required=TERM ;;
                *) ignored=HUP; required=TERM ;;
            esac
            conf TARGET "$target"; conf IGNORED_SIGNAL "$ignored"; conf REQUIRED_SIGNAL "$required"; conf DISTRACTORS 4
            write_level_readme "THE STUBBORN WORKER
The $target worker ignores $ignored. Stop that worker while preserving all
peers. The required final escalation is $required. Verify that an ordinary
signal worked or failed before escalating.
Useful commands: ps, kill, kill -l."
            ;;
        4)
            target=$(role_at 3); heartbeat="heartbeat-$(hex_fragment heartbeat 6).log"
            conf TARGET "$target"; conf HEARTBEAT "$heartbeat"; conf INTERVAL "$((1 + $(hex_byte "$(derive_hex interval)" 0) % 3))"
            conf REQUIRED "stop-then-continue"; conf DISTRACTORS 3
            write_level_readme "PAUSE AND RESUME
Temporarily stop $target, confirm its state becomes T and its heartbeat pauses,
then continue it. It must be running when checked. Preserve its peers.
Useful commands: ps, kill, tail."
            ;;
        5)
            base=$(( $(hex_byte "$(derive_hex job-layout)" 0) % 6 ))
            a=$(role_from_index "$base"); b=$(role_from_index "$((base + 1))")
            conf JOB_A "$a"; conf JOB_B "$b"
            conf TARGET_JOB "$b"; conf REQUIRED_STATE running
            write_level_readme "FOREGROUND AND BACKGROUND JOBS
startlevel launches $a and $b as jobs in your current interactive shell.
Use jobs to inspect them. Stop $a and leave it stopped; leave $b running in
the background. checklevel validates both job processes.
Useful commands: jobs, fg, Ctrl-Z, bg, kill."
            ;;
        6)
            target=$(role_at 5); nice=$((8 + $(hex_byte "$(derive_hex niceness)" 0) % 8))
            conf TARGET "$target"; conf REQUIRED_NICE "$nice"; conf DISTRACTORS 4
            write_level_readme "CONTROL THE RESOURCE HOG
Observe the workers and identify the one consuming the most CPU. Its role is
not disclosed by the briefing. Lower its scheduling priority by setting its
nice value to $nice. Keep every worker alive.
Useful commands: top, ps, nice, renice."
            ;;
        7)
            base=$(( $(hex_byte "$(derive_hex tree-layout)" 0) % 6 ))
            parent=$(role_from_index "$base")
            target=$(role_from_index "$((base + 1))")
            protect=$(role_from_index "$((base + 2))")
            conf PARENT "$parent"; conf TARGET_BRANCH "$target"; conf PROTECTED_BRANCH "$protect"
            conf CHILDREN "$((2 + $(hex_byte "$(derive_hex children)" 0) % 2))"
            write_level_readme "PARENT, CHILD, AND BRANCH
Map the process tree rooted at $parent. Terminate the complete $target branch,
including its children, but preserve the $protect branch and its children.
Useful commands: ps with PID/PPID columns, kill."
            ;;
        8)
            target="group-$(hex_fragment target-group 5)"; protect="group-$(hex_fragment protected-group 5)"
            conf TARGET_GROUP "$target"; conf PROTECTED_GROUP "$protect"
            conf STAGES "$((3 + $(hex_byte "$(derive_hex stages)" 0) % 3))"; conf REQUIRED_SIGNAL TERM
            write_level_readme "PIPELINE AND PROCESS GROUP
Terminate every member of process group label $target with TERM. Preserve all
members of $protect. Discover the numeric PGID and signal the group as a unit.
Useful commands: ps with PID/PGID columns, kill -- -PGID."
            ;;
        9)
            parent=$(role_at 1); child=$(role_at 3)
            control=$(( $(hex_byte "$(derive_hex control)" 0) % 2 ))
            [ "$control" -eq 0 ] && signal=USR1 || signal=CONT
            conf PARENT "$parent"; conf ZOMBIE "$child"; conf CONTROL_SIGNAL "$signal"
            write_level_readme "THE ZOMBIE MYSTERY
Find the zombie child named $child. Sending a signal to the zombie cannot reap
it. Send $signal to its parent $parent so the parent performs wait(2).
Preserve the parent and its live sibling.
Useful commands: ps, kill."
            ;;
        10)
            base=$(( $(hex_byte "$(derive_hex incident-layout)" 0) % 6 ))
            hog=$(role_from_index "$base")
            paused=$(role_from_index "$((base + 1))")
            stubborn=$(role_from_index "$((base + 2))")
            protected=$(role_from_index "$((base + 3))")
            group="group-$(hex_fragment incident-group 5)"
            nice=$((8 + $(hex_byte "$(derive_hex final-nice)" 0) % 8))
            conf HOG "$hog"; conf PAUSED "$paused"; conf STUBBORN "$stubborn"; conf TARGET_GROUP "$group"
            conf REQUIRED_NICE "$nice"; conf PROTECTED "$protected"
            write_level_readme "PROCESS INCIDENT RESPONSE
Restore the $THEME workload:
  1. Set the CPU-heavy worker's nice value to $nice.
  2. Resume the stopped worker.
  3. Terminate every member of group label $group with TERM.
  4. Terminate the worker that ignores TERM, escalating only if necessary.
  5. Preserve the protected worker.
Use ps/top to discover identities; do not assume launch order."
            ;;
        *) die "unknown level $n" ;;
    esac
    level_finish
}
