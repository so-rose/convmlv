#!/bin/bash

#desc: Portable utility functions that could live in their own library.

nFound() { #Prints: ${type} ${name} not found! ${exec_instr}.\n\t${down_instr} to stderr.
	type=$1
	name="$2"
	exec_instr=$3
	down_instr=$4
	
	if [[ -z $down_instr ]]; then
		echo -e "\033[1;31m${type} \033[0;1m${name}\033[1;31m not found! ${exec_instr}.\033[0m\n" >&2
	else
		echo -e "\033[1;31m${type} \033[0;1m${name}\033[1;31m not found! ${exec_instr}.\033[0m\n------> ${down_instr}\n" >&2
	fi
}

mkdirS() {
	#usage: mkdirS path; if [ $? -eq 1 ]; then return 1; fi
	#desc: A function that allows the user to decide whether to overwrite an existing directory.
	#note: The user must use return codes to provide the return from develop().
	#return: Exit code 1 denotes that we must continue.
	
	path=$1
	cleanup=$2
	cont=false
		
	if [ -d $path ]; then
		while true; do
			read -p "Overwrite ${path}? [y/n/q] " ynq
			case $ynq in
				[Yy]* ) echo -e ""; rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
				;;
				[Nn]* ) error "\nDirectory ${path} won't be created.\n"; cont=true; `$cleanup`; break
				;;
				[Qq]* ) error "\nHalting execution. Directory ${path} won't be created.\n"; `$cleanup`; exit 1;
				;;
				* ) error "Please answer yes or no, or quit.\n"
				;;
			esac
		done
	else
		mkdir -p $path >/dev/null 2>/dev/null
	fi
	
	if [ $cont == true ]; then 
		return 1
	fi
	
}

folderName() {
	#Like basename, but for folders.
	echo "$1" | rev | cut -d$'/' -f1 | rev
}

joinArgs() {
	#Joins the arguments of the input array using commas.
	local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"
}

runSim() {
		# Command: cat $PIPE | cmd1 & cmdOrig | tee $PIPE | cmd2
		
		# cat $PIPE | cmd1 - gives output of pipe live. Pipes it into cmd1. Nothing yet; just setup.
		# & - runs the next part in the background.
		# cmdOrig | tee $PIPE | cmd2 - cmdOrig pipes into the tee, which splits it back into the previous pipe, piping on to cmd2!
		
		# End Result: Output of cmdOrig is piped into cmd1 and cmd2, which execute, both printing to stdout.
		
		cmdOrig=$1
		cmd1=$2
		cmd2=$3
		
		#~ echo $cmdOrig $cmd1 $cmd2
		#~ echo $($cmdOrig)
		
		PIPE="${TMP}/pipe_vid" # $(date +%s%N | cut -b1-13)"
		mkfifo $PIPE 2>/dev/null
		
		cat $PIPE | $cmd1 & $cmdOrig | tee $PIPE | $cmd2 #The magic of simultaneous execution ^_^
		#~ cat $PIPE | tr 'e' 'a' & echo 'hello' | tee $PIPE | tr 'e' 'o' #The magic of simultaneous execution ^_^
	}

strArr() {
	#usage: strArr arg1 arg2 ...
	#desc: Formats the args into a string ready to insert into an associative array.
	#return: A string ready to insert into an associative array.
	
	echo "TO BE WRITTEN"
}
