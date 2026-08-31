#!/bin/sh
PS1='\W$ '
cd "$HOME" || exit 1

startlevel() {
    . /usr/lib/process-lab/startlevel.sh
}

clear
echo "************************************************************************"
echo "* PolyLinux Processes and Job Control                                  *"
echo "* Inspect and manage disposable exercise processes.                    *"
echo "* Read README.txt, then run startlevel.                                 *"
echo "* Use the external answer form when finished; move with nextlevel and prevlevel.      *"
echo "************************************************************************"
cat README.txt
