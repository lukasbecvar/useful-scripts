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

		# delete others directories
		sudo rm -rf ~/.audacity-data
		sudo rm -rf ~/.dbclient
		sudo rm -rf ~/.android
		sudo rm -rf ~/.mozilla
		sudo rm -rf ~/.docker
		sudo rm -rf ~/.dotnet
		sudo rm -rf ~/.java
		sudo rm -rf ~/.npm

		# delete others files
		sudo rm -rf ~/.sudo_as_admin_successful
		sudo rm -rf ~/.xsession-errors
		sudo rm -rf ~/.python_history
		sudo rm -rf ~/.Xauthority
		sudo rm -rf ~/.wget-hsts
		sudo rm -rf ~/.gtkrc-2.0
		sudo rm -rf ~/.lesshst

		# poweroff
		echo "poweroff system!!!"
		#sudo poweroff
		sudo reboot
	;;
    no|NO)
		echo "Process exited."
   	;;
    *)
		echo "Your vote not found!\n"
    ;;
esac
