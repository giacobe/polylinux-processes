#!/bin/sh
set -eu
cd "$(dirname "$0")"
tmp=$(mktemp -d)
target_pid=
peer_pid=
stubborn_pid=
cleanup() {
    [ -z "$target_pid" ] || kill -KILL "$target_pid" 2>/dev/null || true
    [ -z "$peer_pid" ] || kill -KILL "$peer_pid" 2>/dev/null || true
    [ -z "$stubborn_pid" ] || kill -KILL "$stubborn_pid" 2>/dev/null || true
    rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

${CC:-cc} -Wall -Wextra -o "$tmp/process-helper" process-helper.c
"$tmp/process-helper" worker "$tmp" target token - 1 receipt <<EOF >>"$tmp/output" 2>&1 &
ignore-hup
EOF
target_pid=$!
"$tmp/process-helper" worker "$tmp" peer token - 1 receipt <<EOF >>"$tmp/output" 2>&1 &
normal
EOF
peer_pid=$!
"$tmp/process-helper" worker "$tmp" stubborn token - 1 receipt <<EOF >>"$tmp/output" 2>&1 &
ignore-term
EOF
stubborn_pid=$!
sleep 1

target_args=$(ps -o args= -p "$target_pid")
peer_args=$(ps -o args= -p "$peer_pid")
stubborn_args=$(ps -o args= -p "$stubborn_pid")
case "$target_args" in *ignore-hup*|*normal*) exit 1 ;; esac
case "$peer_args" in *ignore-hup*|*normal*) exit 1 ;; esac
case "$stubborn_args" in *ignore-term*|*normal*) exit 1 ;; esac
case "$target_args" in *' target token - 1 receipt') ;; *) exit 1 ;; esac
case "$peer_args" in *' peer token - 1 receipt') ;; *) exit 1 ;; esac
case "$stubborn_args" in *' stubborn token - 1 receipt') ;; *) exit 1 ;; esac

kill -HUP "$target_pid"
sleep 1
kill -0 "$target_pid"
kill -0 "$peer_pid"
kill -TERM "$target_pid"
wait "$target_pid"
grep -q '^target .* ignored=1$' "$tmp/events"
grep -q '^target .* signal=15$' "$tmp/events"
kill -0 "$peer_pid"
kill -TERM "$stubborn_pid"
sleep 1
kill -0 "$stubborn_pid"
grep -q '^stubborn .* ignored=15$' "$tmp/events"
echo 'Hidden worker behavior and signal events passed.'
