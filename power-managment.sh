#!/bin/bash

clear

# get corec count
core_count=$(nproc)

# print core modes
print_current_gov() {
    sleep 3
    for i in $(seq 0 $(($core_count - 1))); do
        echo "core $i: $(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor)"
    done
}

# enable powersave
enable_power_save() {
    for i in $(seq 0 $(($core_count - 1))); do
        sudo bash -c "echo powersave > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
    done
    print_current_gov
}

# disable powersave
disable_power_save() {
    for i in $(seq 0 $(($core_count - 1))); do
        sudo bash -c "echo performance > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
    done
    print_current_gov
}

auto_switch() {
	# get current gov
    current_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

	# set cpu mode
    for i in $(seq 0 $(($core_count - 1))); do
        if [ "$current_gov" = "powersave" ]; then
            sudo bash -c "echo performance > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
        else
            sudo bash -c "echo powersave > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
		fi
    done

    print_current_gov

	# show alert
	if [ "$current_gov" = "powersave" ]; then
		kdialog --msgbox 'PowerMode: powersave disabled'
	else
		kdialog --msgbox 'PowerMode: powersave enabled'
	fi
}

echo "\033[33m\033[1m╔═══════════════════════════════════════════════════╗\033[0m"
echo "\033[33m\033[1m║\033[1m                  \033[32mPOWER-MANAGEMENT\033[0m                 \033[33m\033[1m║\033[0m"
echo "\033[33m\033[1m╠═══════════════════════════════════════════════════╣\033[0m"
echo "\033[33m\033[1m║\033[1m  \033[34m1 - Powersave\033[1m   \033[34m2 - Performance\033[1m   \033[34m3 - Auto\033[0m       \033[33m\033[1m║\033[0m"
echo "\033[33m\033[1m╠═══════════════════════════════════════════════════╣\033[0m"
echo "\033[33m\033[1m║\033[1m  \033[34m0 - Exit panel\033[0m                                   \033[33m\033[1m║\033[0m"
echo "\033[33m\033[1m╚═══════════════════════════════════════════════════╝\033[0m"

if [ "$#" -eq 0 ]; then
	read -p "Enter action number: " num
else
	num=$1
fi

case $num in
	# set powersave mode
	1)
		enable_power_save
	;;
	# set performance mode
	2)
    	disable_power_save
    ;;
	# automatic switch
	3)
    	auto_switch
    ;;

	# panel exit
	0)
    	exit
    ;;
	# not found num
	*)
    	red_echo "$num: not found"
    ;;
esac
