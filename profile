#!/bin/sh
. /etc/profile.d/polylinux-colors.sh
PS1='\W$ '
cd "$HOME" || exit 1

startlevel() {
    . /usr/lib/process-lab/startlevel.sh
}
validate() {
    if [ "${USER#level}" = 5 ] && [ -d "$HOME/runtime" ]; then
        jobs -l > "$HOME/runtime/jobs-snapshot"
    fi
    /usr/bin/process-validate "$@"
}
clear
box_line() { printf '* %-36.36s *\n' "$1"; }
echo '****************************************'
box_line 'PolyLinux: Processes/Job Control'
box_line 'Read README, then run startlevel.'
box_line 'Run validate for a submission key.'
box_line 'Use nextlevel and prevlevel.'
echo '****************************************'
cat README.txt
