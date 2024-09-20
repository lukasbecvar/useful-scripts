#!/bin/bash

# script for downloading all installed deb packages (only for apt)

# clear console
clear

echo "Do you want to download all installed packages?"
echo "[YES or NO]: "

read selector

case $selector in
    yes|YES)
        # get installed packages list
        dpkg --get-selections > installed-packages.txt

        # download all packages
        for package in $(awk '{print $1}' installed-packages.txt); do
            echo "Downloading $package..."
            sudo apt-get download "$package" 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "Skipping $package, package not found."
            fi
        done
    ;;
    no|NO)
        echo "Process exited."
    ;;
    *)
        echo "Your choice not found!"
    ;;
esac
