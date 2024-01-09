#!/bin/bash

# script for download all instaled deb packages (only for apt)

# clear console
clear

echo "Do you want download all instaled packages?\n"
echo "[YES or NO]: "

read selector

case $selector in
        yes|YES)
		# get installed packages list
		dpkg --get-selections > installed-packages.txt

		# download all packages
		sudo apt-get download $(awk '{print $1}' installed-packages.txt)
        ;;
    no|NO)
                echo "Process exited."
        ;;
    *)
                echo "Your vote not found!\n"
    ;;
esac

