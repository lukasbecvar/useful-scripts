#!/bin/bash

# clear console
clear

echo "Total temp, cache, etc clean, [reboot required!]\n"
echo "[YES or NO]: "

read selector

case $selector in
	yes|YES)
		
		# system update
		echo "System update..."
		sudo apt update -y
		sudo apt upgrade -y
		sudo apt autoremove -y

		# logs delete
		echo "Delete logs..."
		sudo find /var/log -type f -delete

		# temp delete
		echo "Delete temp..."
		sudo rm -r /tmp/*

		# cache & trash files delete
		sudo rm -r ~/.cache/*
		sudo rm -r ~/.local/share/Trash/*

		# poweroff
		echo "poweroff system!!!"
		sudo poweroff
	;;
    no|NO)
		echo "Process exited."
   	;;
    *)
		echo "Your vote not found!\n"
    ;;
esac
