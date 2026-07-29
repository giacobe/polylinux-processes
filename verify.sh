#!/bin/sh
set -eu

HOME_ROOT=${HOME_ROOT:-/home}
ANSWER_DIR=${ANSWER_DIR:-/var/lib/process-lab/answers}
failures=0

check() {
    level=$1
    actual=$2
    expected=$(sed -n '1p' "$ANSWER_DIR/level$level")
    if [ "$actual" = "$expected" ]; then
        echo "level$level: PASS"
    else
        echo "level$level: FAIL" >&2
        echo "  expected: $expected" >&2
        echo "  solver:   $actual" >&2
        failures=$((failures + 1))
    fi
}

# Level 1: correlate the assignment fingerprint with the process inventory.
f="$HOME_ROOT/level1/evidence/process-inventory.txt"
fingerprint=$(sed -n 's/^ASSIGNMENT fingerprint=//p' "$f")
record=$(awk -v fp="$fingerprint" '$1=="PROCESS" && $4=="fingerprint=" fp {print; exit}' "$f")
role=$(printf '%s\n' "$record" | sed 's/.*role=\([^ ]*\).*/\1/')
worker=$(printf '%s\n' "$record" | sed 's/.*worker_id=\([^ ]*\).*/\1/')
state=$(printf '%s\n' "$record" | sed 's/.*state_class=\([^ ]*\).*/\1/')
check 1 "$role|$worker|$state"

# Level 2: identify the graceful policy and count protected peers.
f="$HOME_ROOT/level2/evidence/shutdown-policy.txt"
policy=$(sed -n '/^POLICY /p' "$f")
role=$(printf '%s\n' "$policy" | sed 's/.*role=\([^ ]*\).*/\1/')
signal=$(printf '%s\n' "$policy" | sed 's/.*accepted_signal=\([^ ]*\).*/\1/')
receipt=$(printf '%s\n' "$policy" | sed 's/.*receipt=\([^ ]*\).*/\1/')
count=$(grep -c '^PEER .*protection=preserve$' "$f")
check 2 "$role|$signal|$receipt|$count"

# Level 3: interpret the selected worker's signal behavior.
f="$HOME_ROOT/level3/evidence/signal-policy.txt"
record=$(sed -n '/^WORKER .*behavior=ignores-/p' "$f")
role=$(printf '%s\n' "$record" | sed 's/.*role=\([^ ]*\).*/\1/')
ignored=$(printf '%s\n' "$record" | sed 's/.*behavior=ignores-\([^ ]*\).*/\1/')
final=$(printf '%s\n' "$record" | sed 's/.*escalation=\([^ ]*\).*/\1/')
check 3 "$role|$ignored|$final"

# Level 4: read the required state transition and its heartbeat artifact.
f="$HOME_ROOT/level4/evidence/heartbeat-policy.txt"
record=$(sed -n '/^HEARTBEAT /p' "$f")
role=$(printf '%s\n' "$record" | sed 's/.*role=\([^ ]*\).*/\1/')
heartbeat=$(printf '%s\n' "$record" | sed 's/.*file=\([^ ]*\).*/\1/')
check 4 "$role|STOP|CONT|$heartbeat"

# Level 5: reconstruct the requested shell-job states.
f="$HOME_ROOT/level5/evidence/job-policy.txt"
stopped=$(awk '$1=="JOB" && $3=="required_state=stopped" {print $2 "|" $4}' "$f" |
    sed 's/role=//; s/|canonical_state=/|/')
running=$(awk '$1=="JOB" && $3=="required_state=running-background" {print $2 "|" $4}' "$f" |
    sed 's/role=//; s/|canonical_state=/|/')
stopped_role=$(printf '%s' "$stopped" | cut -d '|' -f 1)
stopped_state=$(printf '%s' "$stopped" | cut -d '|' -f 2)
running_role=$(printf '%s' "$running" | cut -d '|' -f 1)
running_state=$(printf '%s' "$running" | cut -d '|' -f 2)
check 5 "$stopped_role|$stopped_state|$running_role|$running_state"

# Level 6: select the highest-CPU sample and interpret the nice policy.
f="$HOME_ROOT/level6/evidence/scheduling-snapshot.txt"
record=$(sed -n '/^SAMPLE .*cpu_class=highest /p' "$f")
role=$(printf '%s\n' "$record" | sed 's/.*role=\([^ ]*\).*/\1/')
nice=$(printf '%s\n' "$record" | sed 's/.*required_nice=\([^ ]*\).*/\1/')
effect=$(printf '%s\n' "$record" | sed 's/.*effect=\([^ ]*\).*/\1/')
check 6 "$role|$nice|$effect"

# Level 7: follow the target and protected branches from the tree evidence.
f="$HOME_ROOT/level7/evidence/process-tree.txt"
parent=$(sed -n 's/^NODE role=\([^ ]*\) relation=root$/\1/p' "$f")
target_record=$(sed -n '/relation=target-branch/p' "$f")
protected_record=$(sed -n '/relation=protected-branch/p' "$f")
target=$(printf '%s\n' "$target_record" | sed 's/.*role=\([^ ]*\).*/\1/')
children=$(printf '%s\n' "$target_record" | sed 's/.*children=\([^ ]*\).*/\1/')
protected=$(printf '%s\n' "$protected_record" | sed 's/.*role=\([^ ]*\).*/\1/')
check 7 "$parent|$target|$children|$protected"

# Level 8: select the group marked for termination and preserve its peer.
f="$HOME_ROOT/level8/evidence/process-groups.txt"
target_record=$(sed -n '/ action=TERM$/p' "$f")
protected_record=$(sed -n '/ action=preserve$/p' "$f")
target=$(printf '%s\n' "$target_record" | sed 's/.*label=\([^ ]*\).*/\1/')
members=$(printf '%s\n' "$target_record" | sed 's/.*members=\([^ ]*\).*/\1/')
protected=$(printf '%s\n' "$protected_record" | sed 's/.*label=\([^ ]*\).*/\1/')
check 8 "$target|$members|TERM|$protected"

# Level 9: identify the zombie, its parent, and the parent's control policy.
f="$HOME_ROOT/level9/evidence/zombie-snapshot.txt"
zombie_record=$(sed -n '/ state=Z /p' "$f")
zombie=$(printf '%s\n' "$zombie_record" | sed 's/.*role=\([^ ]*\).*/\1/')
parent=$(printf '%s\n' "$zombie_record" | sed 's/.*parent=\([^ ]*\).*/\1/')
parent_record=$(awk -v role="$parent" '$1=="PROCESS" && $2=="role=" role {print}' "$f")
signal=$(printf '%s\n' "$parent_record" | sed 's/.*control_signal=\([^ ]*\).*/\1/')
check 9 "$zombie|$parent|$signal|reap"

# Level 10: construct the canonical response plan in objective order.
f="$HOME_ROOT/level10/evidence/incident-evidence.txt"
hog=$(sed -n 's/^OBJECT role=\([^ ]*\) condition=cpu-heavy action=renice value=\([^ ]*\)$/\1@\2/p' "$f")
paused=$(sed -n 's/^OBJECT role=\([^ ]*\) condition=stopped action=CONT$/\1@CONT/p' "$f")
group=$(sed -n 's/^OBJECT role=\([^ ]*\) condition=process-group action=TERM$/\1@TERM/p' "$f")
stubborn=$(sed -n 's/^OBJECT role=\([^ ]*\) condition=ignores-TERM action=TERM>KILL$/\1@TERM>KILL/p' "$f")
protected=$(sed -n 's/^OBJECT role=\([^ ]*\) condition=protected action=KEEP$/\1@KEEP/p' "$f")
check 10 "$hog;$paused;$group;$stubborn;$protected"

[ "$failures" -eq 0 ] || exit 1
echo "All evidence-derived answers passed."
