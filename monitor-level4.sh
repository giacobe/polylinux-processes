#!/bin/sh
# Observe a real stopped-to-resumed transition without recording volatile PIDs.
run=$1
target=$2
pid=
i=0
while [ -z "$pid" ] && [ "$i" -lt 30 ]; do
    pid=$(awk -v role="$target" '$1 == role {print $2; exit}' "$run/registry" 2>/dev/null)
    [ -n "$pid" ] || sleep 1
    i=$((i+1))
done
[ -n "$pid" ] || exit 1
seen_stop=0
while [ -r "/proc/$pid/stat" ]; do
    state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null)
    case "$state" in
        T|t)
            if [ "$seen_stop" -eq 0 ]; then
                printf 'stopped\n' > "$run/level4-transitions"
                seen_stop=1
            fi
            ;;
        Z|X|x|'') exit 0 ;;
        *)
            if [ "$seen_stop" -eq 1 ]; then
                printf 'stopped-resumed\n' > "$run/level4-transitions"
                exit 0
            fi
            ;;
    esac
    sleep 1
done
