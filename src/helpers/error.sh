#!/bin/bash

#desc: Error checking and consequence functions.

invOption() {
	str=$1
	
	echo -e "\033[0;31m\033[1m${str}\033[0m"
	
	echo -e "\n\033[1mCleaning Up.\033[0m\n\n"
	
	#Delete tmp
	rm -rf $TMP
	
	exit 1
}

checkArg() {
	#usage: checkArg arg
	#desc: Checks the argument to see if it's a valid MLV, RAW, or DNG sequence.
	#return: 'false' if not valid, 'true' if it is.
	#print (stderr): Error stuff.
	
	local arg="$1"
	
	local argBase="$(basename "$arg")"
	local argExt="${argBase##*.}"
	local argTrunc="${argBase%.*}"
	local cont
	
	#Argument Checks
	if [ ! -f $arg ] && [ ! -d $arg ]; then
		nFound "File" "${arg}" "Skipping File"
		echo "false" >&1; return
	fi
	
	if [[ ! -d $arg && ! ( $argExt == "MLV" || $argExt == "mlv" || $argExt == "RAW" || $argExt == "raw" ) ]]; then
		error "File ${arg} has invalid extension!\n" >&2
		echo "false" >&1; return
	fi
	
	if [[ ( ( ! -f $arg ) && $(ls -1 ${arg%/}/*.[Dd][Nn][Gg] 2>/dev/null | wc -l) == 0 ) && ( `folderName ${arg}` != $argTrunc ) ]]; then
		error "Folder ${arg} contains no DNG files!" >&2
		echo "false" >&1; return
	fi
	
	if [ ! -d $arg ] && [[ $(echo $(wc -c ${arg} | xargs | cut -d " " -f1) / 1000 | bc) -lt 1000 ]]; then #Check that the file is not too small.
		cont=false
		while true; do
			#xargs easily trims the cut statement, which has a leading whitespace on Mac.
			read -p "${arg} is unusually small at $(echo "$(echo "$(wc -c ${arg})" | xargs | cut -d$' ' -f1) / 1000" | bc)KB. Continue, skip, remove, or quit? [c/s/r/q] " csr
			case $csr in
				[Cc]* ) error "\nContinuing.\n"; break
				;;
				[Ss]* ) error "\nSkipping.\n"; cont=true; break
				;;
				[Rr]* ) error "\nRemoving ${arg}.\n"; cont=true; rm $arg; break
				;;
				[Qq]* ) error "\nQuitting.\n"; isExit=true; break
				;;
				* ) error "Please answer continue, skip, or remove.\n"
				;;
			esac
		done
		
		if [ $cont == true ]; then
			echo "false" >&1; return
		fi
	fi
}

checkDeps() {
		#Essentials
		if [ ! -f $MLV_DUMP ]; then
			nFound "Binary" "${MLV_DUMP}" "Execution will halt" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=7122.0."
			isExit=true
		fi
		if [ ! -d ${COLOR_LUTS[0]} ]; then
			nFound "Folder" "color-core" "Execution will halt" "Download from convmlv repository."
			isExit=true
		fi
		if [ ! -f $PYTHON_SRANGE ]; then
			nFound "Python Script" "${PYTHON_SRANGE}" "Execution will halt" "Download from convmlv repository."
			isExit=true
		fi
		
		cmdExists() { if type -P "$1" &> /dev/null || [ -x "$1" ]; then echo true; else echo false; fi }
		
		#Basic Options - Dist Deps
		if [[ $(cmdExists "$DCRAW") != true ]]; then
			nFound "Command" "$DCRAW" "Execution will halt" "dcraw not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "$PYTHON") != true ]]; then
			nFound "Command" "$PYTHON" "Execution will halt" "Python was not installed correctly. Install version 3.X, or see PYTHON in the OPTIONS, BASIC section of 'convmlv -h' for custom path."
			isExit=true
		fi
		if [[ $(cmdExists "$PYTHON") == true && $($PYTHON -c 'import sys; print(sys.version_info[0])') != 3 ]]; then
			nFound "Python Version" "3.X" "Execution will halt" "Your python version is $($PYTHON -c "import sys; print('.'.join(str(x) for x in sys.version_info[0:3]))") - convmlv requires 3.X. Typically, you must install the 'python3' package; else you can set set PYTHON in the OPTIONS, BASIC section of 'convmlv -h'."
		fi
		if [[ $(cmdExists "convert") != true ]]; then
			nFound "Command" "convert" "Execution will halt" "ImageMagick not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "ffmpeg") != true ]]; then
			nFound "Command" "ffmpeg" "Execution will halt" "ffmpeg not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "exiftool") != true ]]; then
			nFound "Command" "exiftool" "Execution will halt" "exiftool not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		
		#Optionals
		if [ ! -f $RAW_DUMP ]; then
			nFound "Binary" "${RAW_DUMP}" "Execution will continue without .RAW processing capability" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=5404.0."
		fi
		if [ ! -f $MLV_BP ]; then
			nFound "SH Script" "${MLV_BP}" "Execution will continue without badpixel removal capability" "Get it here: https://bitbucket.org/daniel_fort/ml-focus-pixels/src"
		fi
		if [ ! -f $CR_HDR ]; then
			nFound "Binary" "${CR_HDR}" "Execution will continue without Dual ISO processing capability" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=7139.0"
		fi
		if [ ! -f $PYTHON_BAL ]; then
			nFound "Python Script" "${PYTHON_BAL}" "Execution will continue without AWB" "Download from convmlv repository."
		fi
		if [ ! -d ${COLOR_LUTS[1]} ]; then
			nFound "Folder" "color-ext" "Execution will continue without extra gamma/gamut options." "Download from convmlv repository."
		fi
		
		if [[ $isExit == true ]]; then
			echo -e "\033[0;33m\033[1mPlace all binaries in BIN_PATH - ${BIN_PATH} - or give specific paths with the relevant arguments/config options (see 'convmlv -h'). Also, make sure they're executable (run 'chmod +x file').\033[0m\n"
			exit 1
		fi
		
		
		#Option Checking - ideally, we do all of these. For now, I'm bored of it...
			#Check wavelet NR - WAVE_NOISE
			#Check TEMP_NOISE
			#Check HQ_NOISE
			#Check REM_NOISE
			#Check SHARP
			#Check SATPOINT
			#Check WHITE_SPD
			#Check BADPIXEL_PATH
			#Check LUT size.
			#badpixel info.
}
