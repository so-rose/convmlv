#!/bin/bash

getThreads() {
	local threads=4 #4 threads by default
	
	if [[ $OSTYPE == "linux-gnu" ]]; then #Linux-specific constants.
		threads=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1)
	elif [[ $OSTYPE == "darwin11" ]]; then #Mac-specific constants
		threads=$(sysctl -n hw.ncpu)
	fi
	
	echo "$threads"
}
