
invOption() {
	str=$1
	
	echo -e "\033[0;31m\033[1m${str}\033[0m"
	
	echo -e "\n\033[1mCleaning Up.\033[0m\n\n"
	
	#Delete tmp
	rm -rf $TMP
	
	exit 1
}

checkArg() {
	#stderr is for printing; stdout is for return values.
	
	argBase="$(basename "$ARG")"
	argExt="${argBase##*.}"
	argTrunc="${argBase%.*}"
	local cont
	
	#Argument Checks
	if [ ! -f $ARG ] && [ ! -d $ARG ]; then
		nFound "File" "${ARG}" "Skipping File"
		echo "skip" >&1; return
	fi
	
	if [[ ! -d $ARG && ! ( $argExt == "MLV" || $argExt == "mlv" || $argExt == "RAW" || $argExt == "raw" ) ]]; then
		echo -e "\033[0;31m\033[1mFile ${ARG} has invalid extension!\033[0m\n" >&2
		echo "skip" >&1; return
	fi
	
	if [[ ( ( ! -f $ARG ) && $(ls -1 ${ARG%/}/*.[Dd][Nn][Gg] 2>/dev/null | wc -l) == 0 ) && ( `folderName ${ARG}` != $argTrunc ) ]]; then
		echo -e "\033[0;31m\033[1mFolder ${ARG} contains no DNG files!\033[0m\n" >&2
		echo "skip" >&1; return
	fi
	
	if [ ! -d $ARG ] && [[ $(echo $(wc -c ${ARG} | xargs | cut -d " " -f1) / 1000 | bc) -lt 1000 ]]; then #Check that the file is not too small.
		cont=false
		while true; do
			#xargs easily trims the cut statement, which has a leading whitespace on Mac.
			read -p "${ARG} is unusually small at $(echo "$(echo "$(wc -c ${ARG})" | xargs | cut -d$' ' -f1) / 1000" | bc)KB. Continue, skip, remove, or quit? [c/s/r/q] " csr
			case $csr in
				[Cc]* ) "\n\033[0;31m\033[1mContinuing.\033[0m\n"; break
				;;
				[Ss]* ) echo -e "\n\033[0;31m\033[1mSkipping.\033[0m\n"; cont=true; break
				;;
				[Rr]* ) echo -e "\n\033[0;31m\033[1mRemoving ${ARG}.\033[0m\n"; cont=true; rm $ARG; break
				;;
				[Qq]* ) echo -e "\n\033[0;31m\033[1mQuitting.\033[0m\n"; isExit=true; break
				;;
				* ) echo -e "\033[0;31m\033[1mPlease answer continue, skip, or remove.\033[0m\n"
				;;
			esac
		done
		
		if [ $cont == true ]; then
			echo "skip" >&1; return
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
