#!/bin/bash

# RAM threshold in MB (e.g., 20 GB = 20480)
THRESHOLD=20480
INTERVAL=2
alert_sent=false

# ANSI colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# RAM status header
print_header() {
	echo -e "${BOLD}${CYAN}==[ RAM WATCHDOG ]==${RESET}"
}

# log ram status
log_ram() {
	read total used free <<<$(free -m | awk '/^Mem:/ { print $2, $3, $4 }')
	echo -e "${YELLOW}Time: $(date '+%H:%M:%S')${RESET}"
	echo -e "${GREEN}Total RAM:${RESET} ${total} MB"
	echo -e "${CYAN}Used RAM:${RESET}  ${used} MB"
	echo -e "${YELLOW}Free RAM:${RESET}  ${free} MB"
	echo ""
}

while true; do
	clear
	print_header
	log_ram

	used_ram=$(free -m | awk '/^Mem:/ { print $3 }')

	if [ "$used_ram" -gt "$THRESHOLD" ]; then
		if [ "$alert_sent" = false ]; then
	  		echo -e "${RED}${BOLD}⚠️ RAM usage exceeded ${THRESHOLD}MB! Triggering notification...${RESET}"
	  		zenity --warning --title="💥 RAM WARNING" --text="Your RAM usage is ${used_ram}MB!"
	  		alert_sent=true
		else
			echo -e "${RED}⛔ Already – holding off spam...${RESET}"
		fi
 	else
		echo -e "${GREEN}✅ RAM under control. All good.${RESET}"
		alert_sent=false
	fi
	sleep $INTERVAL
done
