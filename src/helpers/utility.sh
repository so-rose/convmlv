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
	path=$1
	cleanup=$2
	cont=false
		
	if [ -d $path ]; then
		while true; do
			read -p "Overwrite ${path}? [y/n/q] " ynq
			case $ynq in
				[Yy]* ) echo -e ""; rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
				;;
				[Nn]* ) echo -e "\n\033[0;31m\033[1mDirectory ${path} won't be created.\033[0m\n"; cont=true; `$cleanup`; break
				;;
				[Qq]* ) echo -e "\n\033[0;31m\033[1mHalting execution. Directory ${path} won't be created.\033[0m\n"; `$cleanup`; exit 1;
				;;
				* ) echo -e "\033[0;31m\033[1mPlease answer yes or no.\033[0m\n"
				;;
			esac
		done
	else
		mkdir -p $path >/dev/null 2>/dev/null
	fi
	
	if [ $cont == true ]; then 
		let ARGNUM--
		continue
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
