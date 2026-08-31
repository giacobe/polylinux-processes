#!/bin/sh
PS1='\W$ '
cd "$HOME" || exit 1

startlevel() {
    . /usr/lib/process-lab/startlevel.sh
}
clear
box_line() { printf '* %-36.36s *\n' "$1"; }
echo '****************************************'
box_line 'PolyLinux: Processes/Job Control'
box_line 'Read README, then run startlevel.'
box_line 'Use the exercise grading form.'
box_line 'Use nextlevel and prevlevel.'
echo '****************************************'
cat README.txt
