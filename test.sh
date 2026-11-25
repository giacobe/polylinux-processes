#!/bin/sh
set -eu
cd "$(dirname "$0")"
. ./polylinux-common.sh

LAB_ID=${LAB_ID:-process-lab}
USER_ID=$(normalize_email '  Student@Example.EDU  ')
currentDate=2026-08-30
SYSTEM_PASSWORD='systemPassword'
levelPassword='levelPassword1'
levelnumber=1
export LAB_ID USER_ID currentDate SYSTEM_PASSWORD levelPassword levelnumber

[ "$USER_ID" = 'student@example.edu' ]
[ "$(exercise_code_from_date "$currentDate")" = '13527DE' ]
seed_a=$(level_seed_v1)
seed_b=$(level_seed_v1)
[ "$seed_a" = "$seed_b" ]

seen='|'
index=0
while [ "$index" -lt 16 ]; do
    THEME_INDEX=$index
    export THEME_INDEX
    id=$(theme_field id)
    case "$seen" in *"|$id|"*) echo "duplicate theme id: $id" >&2; exit 1 ;; esac
    seen="$seen$id|"
    for field in title org place system project asset event status service host file person; do
        [ -n "$(theme_field "$field")" ]
    done
    index=$((index + 1))
done

for level in 1 2 3 4 5 6 7 8 9 10; do
    sh -n "./level$level.sh"
done
sh -n ./install.sh ./resources.sh ./polylinux-common.sh ./polylinux-parallel-runtime.sh \
    ./startlevel.sh ./monitor-level4.sh ./validate ./profile

# Level 1 must identify one live target among distinct seeded decoys, with a
# target position that varies across learners instead of always launching first.
first_position=; varied_position=0
for learner in student@example.edu learner2@example.edu learner3@example.edu; do
    case_dir=$(mktemp -d)
    (
        export INSTALL_ROOT=$PWD LAB_ID USER_ID="$learner" currentDate SYSTEM_PASSWORD
        export CASE_ROOT="$case_dir/cases" LEVEL_HOME="$case_dir/home" SKIP_OWNERSHIP=1 THEME_INDEX=0
        mkdir -p "$LEVEL_HOME"
        levelnumber=1 levelToBuild=level1 levelPassword=levelPassword1
        export levelnumber levelToBuild levelPassword
        level_HASH=$(level_seed_v1)
        export level_HASH
        . ./resources.sh
        build_level 1
        . "$CASE_ROOT/level1/case.conf"
        set -- $LEVEL1_ROSTER
        [ "$#" -eq "$((DISTRACTORS + 1))" ]
        seen='|'; target_position=0; position=1
        for entry do
            role=${entry%%:*}; token=${entry#*:}
            case "$seen" in *"|$token|"*) exit 1 ;; esac
            seen="$seen$token|"
            if [ "$role" = "$TARGET" ]; then
                [ "$token" = "$TOKEN" ]
                target_position=$position
            else
                [ "$token" != "$TOKEN" ]
            fi
            position=$((position + 1))
        done
        [ "$target_position" -gt 0 ]
        printf '%s\n' "$target_position" > "$case_dir/position"

        levelnumber=2 levelToBuild=level2 levelPassword=levelPassword2
        level_HASH=$(level_seed_v1)
        LEVEL_HOME="$case_dir/home2"
        export levelnumber levelToBuild levelPassword level_HASH LEVEL_HOME
        mkdir -p "$LEVEL_HOME"
        build_level 2
        . "$CASE_ROOT/level2/case.conf"
        set -- $LEVEL2_ROSTER
        [ "$#" -eq 5 ]
        seen='|'; target_count=0
        for entry do
            role=${entry%%:*}; token=${entry#*:}
            case "$seen" in *"|$token|"*) exit 1 ;; esac
            seen="$seen$token|"
            if [ "$role" = "$TARGET" ]; then
                [ "$token" = "$TOKEN" ]
                target_count=$((target_count + 1))
            else
                [ "$token" != "$TOKEN" ]
            fi
        done
        [ "$target_count" -eq 1 ]
    )
    position=$(cat "$case_dir/position")
    if [ -z "$first_position" ]; then
        first_position=$position
    elif [ "$position" -ne "$first_position" ]; then
        varied_position=1
    fi
    rm -rf "$case_dir"
done
[ "$varied_position" -eq 1 ]

if grep -R -n -E 'record_answer|ANSWER_DIR|/answers|checklevel' . \
    --exclude-dir=.git --exclude-dir=provenance --exclude=README.md --exclude=LEVELS.md \
    --exclude=participant-guide.md --exclude=test.sh --exclude=verify.sh; then
    echo 'client-side answer-key reference remains' >&2
    exit 1
fi
echo 'Contract, theme catalog, and shell syntax checks passed.'
sh ./test-hidden-worker.sh
