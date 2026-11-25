#!/bin/sh
. "$INSTALL_ROOT/polylinux-common.sh"

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
        0:roles) echo "star-tracker image-stacker weather-sampler catalog-uplink orbit-monitor archive-writer dome-controller guide-camera focus-monitor time-beacon sky-indexer mirror-control" ;;
        1:name) echo greenhouse ;;
        1:roles) echo "soil-reader pump-controller humidity-probe climate-monitor harvest-logger valve-worker nutrient-mixer vent-controller mist-scheduler lamp-monitor bed-scanner drain-sensor" ;;
        2:name) echo research-vessel ;;
        2:roles) echo "sonar-reader route-recorder telemetry-link depth-monitor sample-indexer deck-sensor ballast-control current-probe winch-monitor chart-writer salinity-probe engine-sampler" ;;
        3:name) echo print-farm ;;
        3:roles) echo "job-router layer-renderer printer-monitor spool-writer material-reader queue-worker nozzle-control bed-calibrator resin-monitor fan-controller plate-scanner motion-planner" ;;
        4:name) echo media-archive ;;
        4:roles) echo "catalog-scan thumb-worker metadata-write ingest-monitor index-builder checksum-read proxy-builder media-probe frame-extract audio-indexer rights-checker archive-mover" ;;
        *) die "unknown theme field $1:$2" ;;
    esac
}

level_begin() {
    LEVEL_DIR="${CASE_ROOT:-/var/lib/process-lab/cases}/$levelToBuild"
    rm -rf "$LEVEL_DIR"
    mkdir -p "$LEVEL_DIR"
    THEME=$(theme_field title)
    ROLES="$(theme_variant system 1) $(theme_variant service 2) $(theme_variant host 3) $(theme_variant asset 4) $(theme_variant event 5) $(theme_variant project 6) $(theme_variant system 7) $(theme_variant service 8) $(theme_variant host 9) $(theme_variant asset 10) $(theme_variant event 11) $(theme_variant project 12)"
    TOKEN=$(hex_fragment identity 10)
    case "$USER_ID" in *"'"*) die "learner identity may not contain a single quote" ;; esac
    printf "LEVEL='%s'\nTHEME='%s'\nTOKEN='%s'\nLEARNER_ID='%s'\nEXERCISE_DATE='%s'\n" \
        "$levelnumber" "$THEME" "$TOKEN" "$USER_ID" "$currentDate" > "$LEVEL_DIR/case.conf"
}

conf() {
    case "$2" in
        *"'"*) die "configuration values may not contain a single quote" ;;
    esac
    printf "%s='%s'\n" "$1" "$2" >> "$LEVEL_DIR/case.conf"
}

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

distractor_roles() {
    _target=$1 _count=$2 _label=$3
    set -- $ROLES
    _total=$#
    _start=$(( $(hex_byte "$(derive_hex "$_label")" 0) % _total ))
    _names=
    _offset=0
    while [ "$_count" -gt 0 ]; do
        _candidate=$(role_from_index "$((_start + _offset))")
        _offset=$((_offset + 1))
        [ "$_candidate" = "$_target" ] && continue
        case " $_names " in *" $_candidate "*) continue ;; esac
        _names="${_names}${_names:+ }$_candidate"
        _count=$((_count - 1))
    done
    printf '%s\n' "$_names"
}

write_level_readme() {
    {
        printf '%s\n' "$1"
        echo
        echo "Run 'startlevel' to create or reset this level's processes."
        if [ "$levelnumber" -eq 1 ]; then
            echo "Run 'validate PID' with the target's current PID and record the printed key."
        else
            echo "When finished, run 'validate' and record the printed key."
        fi
        echo "Inspect the current processes with 'ps -ww -o pid,ppid,pgid,stat,ni,comm,args'."
    } > "$LEVEL_HOME/README.txt"
}

evidence_file() {
    printf '%s/evidence/%s\n' "$LEVEL_HOME" "$1"
}

prepare_evidence() {
    mkdir -p "$LEVEL_HOME/evidence"
}

level_finish() {
    cp "$LEVEL_DIR/case.conf" "$LEVEL_HOME/case.conf"
    chmod 644 "$LEVEL_HOME/README.txt" "$LEVEL_HOME/case.conf"
    if [ "${SKIP_OWNERSHIP:-0}" != 1 ]; then
        chown -R "$levelToBuild:$levelToBuild" "$LEVEL_HOME"
        chown -R root:root "$LEVEL_DIR"
        chmod 700 "$LEVEL_HOME"
        find "$LEVEL_HOME/evidence" -type d -exec chmod 700 {} \; 2>/dev/null || true
        find "$LEVEL_HOME/evidence" -type f -exec chmod 600 {} \; 2>/dev/null || true
        chmod 755 "$LEVEL_DIR"
        chmod 644 "$LEVEL_DIR/case.conf"
    fi
}

write_evidence() {
    prepare_evidence
    # Reload the generated case as the evidence writer's input. Learners derive
    # and submit answers from the live process state; no answer key is stored.
    . "$LEVEL_DIR/case.conf"
    case "$levelnumber" in
        1)
            worker_id="wrk-$(hex_fragment worker-target 8)"
            {
                echo "FORMAT role|worker-id|state-class"
                echo "ASSIGNMENT fingerprint=$TOKEN"
                printf 'PROCESS role=%s worker_id=%s fingerprint=%s state_class=sleeping\n' \
                    "$TARGET" "$worker_id" "$TOKEN"
                i=1
                while [ "$i" -le "$DISTRACTORS" ]; do
                    printf 'PROCESS role=decoy-%d worker_id=wrk-%s fingerprint=%s state_class=sleeping\n' \
                        "$i" "$(hex_fragment "worker-decoy-$i" 8)" "$(hex_fragment "decoy-fingerprint-$i" 10)"
                    i=$((i + 1))
                done
            } > "$(evidence_file process-inventory.txt)"
            ;;
        2)
            {
                echo "FORMAT role|signal|receipt-name|protected-count"
                printf 'POLICY role=%s shutdown=graceful accepted_signal=TERM receipt=%s\n' "$TARGET" "$RECEIPT"
                i=1
                while [ "$i" -le "$DISTRACTORS" ]; do
                    printf 'PEER role=peer-%d protection=preserve\n' "$i"
                    i=$((i + 1))
                done
            } > "$(evidence_file shutdown-policy.txt)"
            ;;
        3)
            {
                echo "FORMAT role|ignored-signal|final-signal"
                printf 'WORKER role=%s behavior=ignores-%s escalation=%s\n' \
                    "$TARGET" "$IGNORED_SIGNAL" "$REQUIRED_SIGNAL"
                i=1
                while [ "$i" -le "$DISTRACTORS" ]; do
                    printf 'WORKER role=peer-%d behavior=normal protection=preserve\n' "$i"
                    i=$((i + 1))
                done
            } > "$(evidence_file signal-policy.txt)"
            ;;
        4)
            {
                echo "FORMAT role|stop-signal|continue-signal|heartbeat-name"
                printf 'HEARTBEAT role=%s file=%s interval=%s required_cycle=STOP,CONT\n' \
                    "$TARGET" "$HEARTBEAT" "$INTERVAL"
                i=1
                while [ "$i" -le "$DISTRACTORS" ]; do
                    printf 'PEER role=peer-%d protection=preserve\n' "$i"
                    i=$((i + 1))
                done
            } > "$(evidence_file heartbeat-policy.txt)"
            ;;
        5)
            {
                echo "FORMAT stopped-role|stopped-state|background-role|background-state"
                printf 'JOB role=%s required_state=stopped canonical_state=T\n' "$JOB_A"
                printf 'JOB role=%s required_state=running-background canonical_state=S\n' "$JOB_B"
            } > "$(evidence_file job-policy.txt)"
            ;;
        6)
            {
                echo "FORMAT role|nice-value|scheduling-effect"
                printf 'SAMPLE role=%s cpu_class=highest required_nice=%s effect=lower-priority\n' \
                    "$TARGET" "$REQUIRED_NICE"
                i=1
                while [ "$i" -le "$DISTRACTORS" ]; do
                    printf 'SAMPLE role=worker-%d cpu_class=idle required_action=preserve\n' "$i"
                    i=$((i + 1))
                done
            } > "$(evidence_file scheduling-snapshot.txt)"
            ;;
        7)
            {
                echo "FORMAT parent-role|target-branch|child-count|protected-branch"
                printf 'NODE role=%s relation=root\n' "$PARENT"
                printf 'NODE role=%s relation=target-branch parent=%s children=%s\n' \
                    "$TARGET_BRANCH" "$PARENT" "$CHILDREN"
                i=1
                while [ "$i" -le "$CHILDREN" ]; do
                    printf 'NODE role=%s-child%d relation=child parent=%s\n' \
                        "$TARGET_BRANCH" "$i" "$TARGET_BRANCH"
                    i=$((i + 1))
                done
                printf 'NODE role=%s relation=protected-branch parent=%s children=%s\n' \
                    "$PROTECTED_BRANCH" "$PARENT" "$CHILDREN"
            } > "$(evidence_file process-tree.txt)"
            ;;
        8)
            {
                echo "FORMAT target-label|member-count|signal|protected-label"
                printf 'GROUP label=%s members=%s action=TERM\n' "$TARGET_GROUP" "$STAGES"
                printf 'GROUP label=%s members=%s action=preserve\n' "$PROTECTED_GROUP" "$STAGES"
            } > "$(evidence_file process-groups.txt)"
            ;;
        9)
            {
                echo "FORMAT zombie-role|parent-role|control-signal|resolution"
                printf 'PROCESS role=%s state=Z parent=%s\n' "$ZOMBIE" "$PARENT"
                printf 'PROCESS role=%s state=S control_signal=%s responsibility=wait\n' \
                    "$PARENT" "$CONTROL_SIGNAL"
                echo "PROCESS role=live-sibling state=S protection=preserve"
            } > "$(evidence_file zombie-snapshot.txt)"
            ;;
        10)
            {
                echo "FORMAT hog@nice;paused@CONT;group@TERM;stubborn@TERM>KILL;protected@KEEP"
                printf 'OBJECT role=%s condition=cpu-heavy action=renice value=%s\n' "$HOG" "$REQUIRED_NICE"
                printf 'OBJECT role=%s condition=stopped action=CONT\n' "$PAUSED"
                printf 'OBJECT role=%s condition=process-group action=TERM\n' "$TARGET_GROUP"
                printf 'OBJECT role=%s condition=ignores-TERM action=TERM>KILL\n' "$STUBBORN"
                printf 'OBJECT role=%s condition=protected action=KEEP\n' "$PROTECTED"
            } > "$(evidence_file incident-evidence.txt)"
            ;;
        *) die "cannot write evidence for level $levelnumber" ;;
    esac
}

build_level() {
    n=$1
    levelnumber=$n
    level_begin
    case "$n" in
        1)
            target=$(role_at 0); count="$((4 + $(hex_byte "$(derive_hex count)" 0) % 4))"
            conf TARGET "$target"; conf DISTRACTORS "$count"
            decoy_roles=$(distractor_roles "$target" "$count" level1-roster)
            conf DISTRACTOR_ROLES "$decoy_roles"
            decoy_entries=; i=1
            for decoy_role in $decoy_roles; do
                decoy_entries="${decoy_entries}${decoy_entries:+ }$decoy_role:$(hex_fragment "decoy-fingerprint-$i" 10)"
                i=$((i + 1))
            done
            target_slot=$(( $(hex_byte "$(derive_hex target-slot)" 0) % (count + 1) ))
            set -- $decoy_entries
            level1_roster=; i=0
            while [ "$i" -le "$count" ]; do
                if [ "$i" -eq "$target_slot" ]; then
                    entry="$target:$TOKEN"
                else
                    entry=$1; shift
                fi
                level1_roster="${level1_roster}${level1_roster:+ }$entry"
                i=$((i + 1))
            done
            conf LEVEL1_ROSTER "$level1_roster"
            conf REQUIRED_FIELDS "pid|ppid|state"
            write_level_readme "PROCESS ROLL CALL
Locate the process whose command contains role=$target and token=$TOKEN.
Pass its live PID to 'validate PID' to obtain a submission key.
Useful commands: ps, grep."
            ;;
        2)
            target=$(role_at 1); receipt="shutdown-$(hex_fragment receipt 6).log"
            conf TARGET "$target"; conf RECEIPT "$receipt"; conf DISTRACTORS 4
            decoy_roles=$(distractor_roles "$target" 4 level2-roster)
            conf DISTRACTOR_ROLES "$decoy_roles"
            decoy_entries=; i=1
            for decoy_role in $decoy_roles; do
                decoy_entries="${decoy_entries}${decoy_entries:+ }$decoy_role:$(hex_fragment "level2-decoy-$i" 10)"
                i=$((i + 1))
            done
            target_slot=$(( $(hex_byte "$(derive_hex level2-target-slot)" 0) % 5 ))
            set -- $decoy_entries
            level2_roster=; i=0
            while [ "$i" -le 4 ]; do
                if [ "$i" -eq "$target_slot" ]; then entry="$target:$TOKEN"; else entry=$1; shift; fi
                level2_roster="${level2_roster}${level2_roster:+ }$entry"
                i=$((i + 1))
            done
            conf LEVEL2_ROSTER "$level2_roster"
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
            case "$ignored" in
                HUP) signal_note="HUP means hangup; it originally reported a disconnected terminal.
Plain 'kill PID' sends TERM instead, so it skips this HUP test." ;;
                INT) signal_note="INT means interrupt. Plain 'kill PID' sends TERM instead,
so it skips this INT test." ;;
                TERM) signal_note="TERM requests a normal shutdown. Plain 'kill PID' sends TERM,
so it can be used for this first test." ;;
            esac
            conf TARGET "$target"; conf IGNORED_SIGNAL "$ignored"; conf REQUIRED_SIGNAL "$required"; conf DISTRACTORS 4
            conf DISTRACTOR_ROLES "$(distractor_roles "$target" 4 level3-roster)"
            write_level_readme "THE STUBBORN WORKER
The $target worker ignores $ignored. Find its current PID with ps. Send
'kill -$ignored PID' first, then check with ps that it is still alive.
Next send 'kill -$required PID' and confirm it exits. Preserve every peer.
$signal_note
'kill -9 PID' sends KILL, which cannot be handled for a clean shutdown.
Use KILL only when it is the required final signal, after the first test.
Useful commands: ps, kill, kill -l."
            ;;
        4)
            target=$(role_at 3); heartbeat="heartbeat-$(hex_fragment heartbeat 6).log"
            conf TARGET "$target"; conf HEARTBEAT "$heartbeat"; conf INTERVAL "$((1 + $(hex_byte "$(derive_hex interval)" 0) % 3))"
            conf REQUIRED "stop-then-continue"; conf DISTRACTORS 3
            conf DISTRACTOR_ROLES "$(distractor_roles "$target" 3 level4-roster)"
            write_level_readme "PAUSE AND RESUME
Temporarily stop $target, confirm its state becomes T and its heartbeat pauses,
leave it stopped for at least two seconds, then continue it. It must be running
when checked. Preserve its peers.
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
the background. Record the requested states.
Useful commands: jobs, fg, Ctrl-Z, bg, kill."
            ;;
        6)
            target=$(role_at 5); nice=$((8 + $(hex_byte "$(derive_hex niceness)" 0) % 8))
            conf TARGET "$target"; conf REQUIRED_NICE "$nice"; conf DISTRACTORS 4
            conf DISTRACTOR_ROLES "$(distractor_roles "$target" 4 level6-roster)"
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
    write_evidence
    # The live process exercise uses case.conf plus processes started by
    # startlevel. Remove construction-only evidence before handing off.
    rm -rf "$LEVEL_HOME/evidence"
    level_finish
}

# Override the legacy catalog above with the shared themes-v1 catalog.
. "$INSTALL_ROOT/polylinux-common.sh"
