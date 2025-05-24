#!/bin/bash

# clear system temp & user home

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

		# delete home directories
		sudo rm -rf ~/.apport-ignore.xml
		sudo rm -rf ~/.xsession-errors
		sudo rm -rf ~/.pam_environment
		sudo rm -rf ~/.python_history
		sudo rm -rf ~/.audacity-data
		sudo rm -rf ~/.Xauthority
		sudo rm -rf ~/.gtkrc-2.0
		sudo rm -rf ~/.wget-hsts
		sudo rm -rf ~/.dbclient
		sudo rm -rf ~/.xinputrc
		sudo rm -rf ~/.minikube
		sudo rm -rf ~/.anydesk
		sudo rm -rf ~/.android
		#sudo rm -rf ~/.mozilla
		sudo rm -rf ~/.lesshst
		sudo rm -rf ~/.docker
		sudo rm -rf ~/.dotnet
		sudo rm -rf ~/.spotdl
		sudo rm -rf ~/.siege
		sudo rm -rf ~/.rpmdb
		sudo rm -rf ~/.cargo
		sudo rm -rf ~/.java
		sudo rm -rf ~/.jdks
		sudo rm -rf ~/.java
		sudo rm -rf ~/.kube
		sudo rm -rf ~/.npm
		sudo rm -rf ~/.pki
		sudo rm -rf ~/.rnd
		sudo rm -rf ~/.m2

		# delete root directories
		sudo rm -rf /root/.python_history
		sudo rm -rf /root/.anydesk
		sudo rm -rf /root/.lesshst
		sudo rm -rf /root/.docker
		sudo rm -rf /root/.cache
		sudo rm -rf /root/.rpmdb
		sudo rm -rf /root/.dbus
		sudo rm -rf /root/.npm

		# poweroff
		echo "poweroff system!!!"
		sudo poweroff
		#sudo reboot
	;;
    no|NO)
		echo "Process exited."
   	;;
    *)
		echo "Your vote not found!\n"
    ;;
esac
