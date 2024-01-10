#!/bin/bash

# Usage: temp_throttle.sh max_temp
# USE CELSIUS TEMPERATURES.
# Original script: https://github.com/Sepero/temp-throttle

# Credits
# Wolfgang Ocker <weo AT weo1 DOT de> - Patch for unspecified cpu frequencies.	

# generic function for printing an error and exiting.
err_exit () {
	echo ""
	echo "\033[31m\033[1m[$(date '+%H:%M:%S')] error\e[0m: $@" 1>&2
	exit 128
}

if [ $# -ne 1 ]; then
	# if temperature wasn't given, then print a message and exit.
	echo "\033[33m\033[1mPlease supply a maximum desired temperature in Celsius.\e[0m" 1>&2
	echo "\033[33m\033[1mFor example: ${0} 60\e[0m	" 1>&2
	exit 2
else
	# set the first argument as the maximum desired temperature.
	MAX_TEMP=$1
fi


### START Initialize Global variables.

# the frequency will increase when low temperature is reached.
LOW_TEMP=$((MAX_TEMP - 5))

CORES=$(nproc) # get number of CPU cores.
echo "\033[33m\033[1mNumber of CPU cores detected: $CORES\033[0m"
CORES=$((CORES - 1)) # subtract 1 from $CORES for easier counting later.

# temperatures internally are calculated to the thousandth.
MAX_TEMP=${MAX_TEMP}000
LOW_TEMP=${LOW_TEMP}000

FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
FREQ_MIN="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"
FREQ_MAX="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"

# store available cpu frequencies in a space separated string FREQ_LIST.
if [ -f $FREQ_FILE ]; then
	# if $FREQ_FILE exists, get frequencies from it.
	FREQ_LIST=$(cat $FREQ_FILE | xargs -n1 | sort -g -r | xargs) || err_exit "Could not read available cpu frequencies from file $FREQ_FILE"
elif [ -f $FREQ_MIN -a -f $FREQ_MAX ]; then
	# else if $FREQ_MIN and $FREQ_MAX exist, generate a list of frequencies between them.
	FREQ_LIST=$(seq $(cat $FREQ_MAX) -100000 $(cat $FREQ_MIN)) || err_exit "Could not compute available cpu frequencies"
else
	err_exit "Could not determine available cpu frequencies"
fi

FREQ_LIST_LEN=$(echo $FREQ_LIST | wc -w)

# CURRENT_FREQ will save the index of the currently used frequency in FREQ_LIST.
CURRENT_FREQ=2

# this is a list of possible locations to read the current system temperature.
TEMPERATURE_FILES="
/sys/class/thermal/thermal_zone0/temp
/sys/class/thermal/thermal_zone1/temp
/sys/class/thermal/thermal_zone2/temp
/sys/class/hwmon/hwmon0/temp1_input
/sys/class/hwmon/hwmon1/temp1_input
/sys/class/hwmon/hwmon2/temp1_input
/sys/class/hwmon/hwmon0/device/temp1_input
/sys/class/hwmon/hwmon1/device/temp1_input
/sys/class/hwmon/hwmon2/device/temp1_input
null
"

# store the first temperature location that exists in the variable TEMP_FILE.
# the location stored in $TEMP_FILE will be used for temperature readings.
for file in $TEMPERATURE_FILES; do
	TEMP_FILE=$file
	[ -f $TEMP_FILE ] && break
done

[ "$TEMP_FILE" = "null" ] && err_exit "The location for temperature reading was not found."




### END Initialize Global variables.


### START define script functions.

# set the maximum frequency for all cpu cores.
set_freq () {
	# from the string FREQ_LIST, we choose the item at index CURRENT_FREQ.
	FREQ_TO_SET=$(echo $FREQ_LIST | cut -d " " -f $CURRENT_FREQ)
	echo $FREQ_TO_SET
	for i in $(seq 0 $CORES); do
		# Try to set core frequency by writing to /sys/devices.
		{ echo $FREQ_TO_SET 2> /dev/null > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq; } ||
		# Else, try to set core frequency using command cpufreq-set.
		{ cpufreq-set -c $i --max $FREQ_TO_SET > /dev/null; } ||
		# Else, return error message.
		{ err_exit "Failed to set frequency CPU core$i. Run script as Root user. Some systems may require to install the package cpufrequtils."; }
	done
}

# will reduce the frequency of cpus if possible.
throttle () {
	if [ $CURRENT_FREQ -lt $FREQ_LIST_LEN ]; then
		CURRENT_FREQ=$((CURRENT_FREQ + 1))
		echo -n "\033[31m\033[1m[$(date '+%H:%M:%S')] throttle \e[0m"
		set_freq $CURRENT_FREQ
	fi
}

# will increase the frequency of cpus if possible.
unthrottle () {
	if [ $CURRENT_FREQ -ne 1 ]; then
		CURRENT_FREQ=$((CURRENT_FREQ - 1))
		echo -n "\033[32m\033[1m[$(date '+%H:%M:%S')] unthrottle \e[0m"
		set_freq $CURRENT_FREQ
	fi
}

get_temp () {
	# het the system temperature. Take the max of all counters
	TEMP=$(cat $TEMPERATURE_FILES 2>/dev/null | xargs -n1 | sort -g -r | head -1)
}

### END define script functions.

echo "\033[33m\033[1mInitialize to max CPU frequency\033[0m"
unthrottle

# main loop
while true; do
	get_temp # gets the current temperature and set it to the variable TEMP.
	if   [ $TEMP -gt $MAX_TEMP ]; then # throttle if too hot.
		throttle
	elif [ $TEMP -le $LOW_TEMP ]; then # unthrottle if cool.
		unthrottle
	fi
	sleep 5 # the amount of time between checking temperatures.
done
