#!/bin/bash

#desc: All config and command line parsing happens here.

#MAIN FUNCTIONS

parseConf() {
	local file=$1 #The File to Parse
	local argOnly=$2 #If true, will only use file-specific blocks. If false, will ignore file-specific blocks.
	local CONFIG_NAME="None"
	
	if [[ -z $file ]]; then return; fi
    if [[ ! -f $file ]]; then return; fi
	
	local fBlock=false #Whether or not we are in a file-specific block.
	local fID="" #The name of the file-specific block we're in.
	
	while IFS="" read -r line || [[ -n "$line" ]]; do
		line=$(echo "$line" | sed -e 's/^[ \t]*//') #Strip leading tabs/whitespaces.
		
		if [[ `echo "${line}" | cut -c1-1` == "#" ]]; then continue; fi #Ignore comments
		
		if [[ `echo "${line}" | cut -c1-1` == "/" ]]; then
			if [[ $fBlock == true ]]; then invOption "ERROR: Nested file-specific blocks in config file $CONFIG_NAME!"; fi
			
			fBlock=true
			fID=`echo "${line}" | cut -d$' ' -f2`
			
			continue
		fi #Enter a file-specific block with /, provided the argument name is correct.
		
		if [[ `echo "${line}" | cut -c1-1` == "*" ]]; then fBlock=false; fID=""; fi #Leave a file-specific block.
		
		#~ echo $argOnly $fBlock $fID ${TRUNC_ARG%.*} `echo "${line}" | cut -d$' ' -f1`
		if [[ ($argOnly == false && $fBlock == false) || ( ($argOnly == true && $fBlock == true) && $fID == ${TRUNC_ARG%.*} ) ]]; then #Conditions under which to write values.
			case `echo "${line}" | cut -d$' ' -f1` in
				"CONFIG_NAME") CONFIG_NAME=`echo "${line}" | cut -d$' ' -f2` #Not doing anything with this right now.
				;;
				"OUTDIR") OUTDIR=`echo "${line}" | cut -d$' ' -f2`
				;;
				"BIN_PATH") BIN_PATH=`echo "${line}" | cut -d$' ' -f2`; setPaths
				;;
				"DCRAW") DCRAW=`echo "${line}" | cut -d$' ' -f2`
				;;
				"MLV_DUMP") MLV_DUMP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"RAW_DUMP") RAW_DUMP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"MLV_BP") MLV_BP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"CR_HDR") CR_HDR=`echo "${line}" | cut -d$' ' -f2`
				;;
				"PYTHON") PYTHON=`echo "${line}" | cut -d$' ' -f2`; setPaths
				;;
				"THREADS") THREADS=`echo "${line}" | cut -d$' ' -f2`
				;;
				
				
				"IMAGE") IMAGES=true
				;;
				"IMG_FMT")
					mode=`echo "${line}" | cut -d$' ' -f2`
					case ${mode} in
						"0") IMG_FMT="exr"
						;;
						"1") IMG_FMT="tiff"
						;;
						"2") IMG_FMT="png"
						;;
						"3") IMG_FMT="dpx"
						;;
						*) invOption "Invalid Image Format Choice: ${mode}"
						;;
					esac
					;;
				"MOVIE") MOVIE=true
				;;
				"PROXY") 
					PROXY=`echo "${line}" | cut -d$' ' -f2`
					case ${PROXY} in
						"0") isJPG=false; isH264=false
						;;
						"1") isJPG=false; isH264=true
						;;
						"2") isJPG=true; isH264=false
						;;
						"3") isJPG=true; isH264=true
						;;
						*) invOption "Invalid Proxy Choice: ${PROXY}"
						;;
					esac
				;;
				"PROXY_SCALE") 
					PROXY_SCALE=`echo "${line}" | cut -d$' ' -f2`
					
					proxy_num=`echo "$PROXY_SCALE" | cut -d'%' -f 1`
					if [[ ! ( ($proxy_num -le 100 && $proxy_num -ge 5) && $proxy_num =~ ^-?[0-9]+$ ) ]]; then invOption "Invalid Proxy Scale: ${PROXY_SCALE}"; fi
				;;
				"KEEP_RAWS") KEEP_DNGS=true
				;;
				"FRAME_RANGE") RANGE_BASE=`echo "${line}" | cut -d$' ' -f2`; isFR=false
				;;
				"UNCOMP") isCOMPRESS=false
				;;
				
				
				"DEMO_MODE") DEMO_MODE=`echo "${line}" | cut -d$' ' -f2`
				;;
				"HIGHLIGHT_MODE") HIGHLIGHT_MODE=`echo "${line}" | cut -d$' ' -f2`
				;;
				"CHROMA_SMOOTH")
					mode=`echo "${line}" | cut -d$' ' -f2`
					case ${mode} in
						"0") CHROMA_SMOOTH="--no-cs"
						;;
						"1") CHROMA_SMOOTH="--cs2x2"
						;;
						"2") CHROMA_SMOOTH="--cs3x3"
						;;
						"3") CHROMA_SMOOTH="--cs5x5"
						;;
						*) invOption "Invalid Chroma Smoothing Choice: ${mode}"
						;;
					esac
				;;
				"WAVE_NOISE") WAVE_NOISE="-n $(echo "${line}" | cut -d$' ' -f2)"
				;;
				"TEMP_NOISE")
					vals="$(echo "${line}" | cut -d$' ' -f2)"
					
					aVal=$(echo "${vals}" | cut -d"-" -f1)
					bVal=$(echo "${vals}" | cut -d"-" -f2)
					
					TEMP_NOISE="atadenoise=0a=${aVal}:0b=${bVal}:1a=${aVal}:1b=${bVal}:2a=${aVal}:2b=${bVal}"
					tempDesc="Temporal Denoiser"
					FFMPEG_FILTERS=true
				;;
				"HQ_NOISE")
					vals="$(echo "${line}" | cut -d$' ' -f2)"
					
					S=`echo "${vals}" | cut -d$':' -f1`
					T=`echo "${vals}" | cut -d$':' -f2`
					
					LS=`echo "${S}" | cut -d$'-' -f1`
					CS=`echo "${S}" | cut -d$'-' -f2`
					LT=`echo "${T}" | cut -d$'-' -f1`
					CT=`echo "${T}" | cut -d$'-' -f2`
					
					HQ_NOISE="hqdn3d=luma_spatial=${LS}:chroma_spatial=${CS}:luma_tmp=${LT}:chroma_tmp=${CT}"
					hqDesc="3D Denoiser"
					FFMPEG_FILTERS=true
				;;
				"REM_NOISE")
					vals="$(echo "${line}" | cut -d$' ' -f2)"
					
					m1=`echo "${vals}" | cut -d$'-' -f1`
					m2=`echo "${vals}" | cut -d$'-' -f2`
					m3=`echo "${vals}" | cut -d$'-' -f3`
					m4=`echo "${vals}" | cut -d$'-' -f4`
					
					REM_NOISE="removegrain=m0=${m1}:m1=${m2}:m2=${m3}:m3=${m4}"
					remDesc="RemoveGrain Modal Denoiser"
					FFMPEG_FILTERS=true
				;;
				"GAMMA") #Value checking done in color management.
					mode=`echo "${line}" | cut -d$' ' -f2`
					
					case ${mode} in
						"0")
							COLOR_GAMMA="STANDARD" #Lets CM know that it should correspond to the gamut, or be 2.2.
						;;
						"1")
							COLOR_GAMMA="lin" #Linear
						;;
						"2")
							COLOR_GAMMA="cineon" #Cineon
						;;
						"3")
							COLOR_GAMMA="clog2" #C-Log2. Req: color-ext.
						;;
						"4")
							COLOR_GAMMA="slog3" #S-Log3. Req: color-ext.
						;;
						#~ "5")
							#~ COLOR_GAMMA="logc" #LogC 4.X . Req: color-ext.
						#~ ;;
						#~ "6")
							#~ COLOR_GAMMA="acescc" #ACEScc Log Gamma. Req: color-aces.
						#~ ;;
						*)
							invOption "g: Invalid Gamma Choice: ${mode}"
						;;
					esac
				;;
				"GAMUT") #Value checking done in color management.
					mode=`echo "${line}" | cut -d$' ' -f2`
					
					case ${mode} in
						"0")
							COLOR_GAMUT="srgb" #sRGB
						;;
						"1")
							COLOR_GAMUT="argb" #Adobe RGB
						;;
						"2")
							COLOR_GAMUT="rec709" #Rec.709
						;;
						"3")
							COLOR_GAMUT="xyz" #XYZ. Linear Only.
						;;
						#~ "3")
							#~ COLOR_GAMUT="aces" #ACES. Standard is Linear. Req: color-aces (all gammas will work, even without color-ext)/
						#~ ;;
						#~ "4")
							#~ COLOR_GAMUT="xyz" #ACES. Standard is Linear. Req: color-aces (all gammas will work, even without color-ext)/
						#~ ;;
						"4")
							COLOR_GAMUT="rec2020" #Rec.2020. Req: color-ext.
						;;
						"5")
							COLOR_GAMUT="dcip3" #DCI-P3. Req: color-ext.
						;;
						"6")
							COLOR_GAMUT="ssg3c" #Sony S-Gamut3.cine. Req: color-ext.
						;;
						*)
							invOption "G: Invalid Gamut Choice: ${mode}"
						;;
					esac
				;;
				"SHALLOW") DEPTH=""; DEPTH_OUT="-depth 8"
				;;
				"WHITE")
					mode=`echo "${line}" | cut -d$' ' -f2`
					case ${mode} in
						"0") CAMERA_WB=false; GEN_WHITE=true #Will generate white balance.
						;;
						"1") CAMERA_WB=true; GEN_WHITE=false; #Will use camera white balance.
						;;
						"2") WHITE="-r 1 1 1 1"; CAMERA_WB=false; GEN_WHITE=false #Will not apply any white balance.
						;;
						*)
							invOption "Invalid White Balance Choice: ${mode}"
						;;
					esac
				;;
				"SHARP")
					val=`echo "${line}" | cut -d$' ' -f2`
					
					lSize=`echo "${val}" | cut -d$':' -f1`
					lStr=`echo "${val}" | cut -d$':' -f2`
					cSize=`echo "${val}" | cut -d$':' -f3`
					cStr=`echo "${val}" | cut -d$':' -f4`
					
					SHARP="unsharp=${lSize}:${lSize}:${lStr}:${cSize}:${cSize}:${cStr}"
					sharpDesc="Sharpen/Blur"
					FFMPEG_FILTERS=true
				;;
				"LUT")
					LUT_PATH=`echo "${line}" | cut -d$' ' -f2`
					
					if [ ! -f $LUT_PATH ]; then invOption "Invalid LUT Path: ${LUT_PATH}"; fi
					
					#Check LUT_SIZE
					i=0
					while read line; do
						sLine=$(echo $line | sed -e 's/^[ \t]*//')
						if [[ $(echo $sLine | cut -c1-11) == "LUT_3D_SIZE" ]]; then
							if [[ $(echo $sLine | cut -c13-) -le 64 && $(echo $sLine | cut -c13-) -ge 2 ]]; then
								break
							else
								size=$(echo $sLine | cut -c13-)
								invOption "$(basename $LUT_PATH): Invalid LUT Size of $size x $size x $size - Must be between x2 and x64 (you can resize using pylut - see 'convmlv -h') ! "
							fi
						elif [[ $i -gt 20 ]]; then
							invOption "$(basename $LUT_PATH): Invalid LUT - LUT_3D_SIZE not found in first 20 non-commented lines."
						fi
						
						if [[ ! $(echo $sLine | cut -c1-1) == "#" ]]; then ((i++)); fi
					done < $LUT_PATH
					
					LUTS+=( "lut3d=${LUT_PATH}" )
					lutDesc="3D LUTs"
					FFMPEG_FILTERS=true
				;;
				"SATPOINT") SATPOINT="-S $(echo "${line}" | cut -d$' ' -f2)"
				;;
				"WHITE_SPD") WHITE_SPD=`echo "${line}" | cut -d$' ' -f2`
				;;
				"WHITE_CLIP") isScale=true
				;;
				
				
				"DESHAKE")
					DESHAKE="deshake"
					deshakeDesc="Deshake Filter"
					FFMPEG_FILTERS=true
				;;
				"DUAL_ISO") DUAL_ISO=true
				;;
				"BADPIXELS") isBP=true
				;;
				"BADPIXEL_PATH") BADPIXEL_PATH=`echo "${line}" | cut -d$' ' -f2`
				;;
				"DARKFRAME")
					DARKFRAME=`echo "${line}" | cut -d$' ' -f2`;
					
					if [ ! -f $DARKFRAME ]; then invOption "Invalid Darkframe: ${DARKFRAME}"; fi
					
					useDF=true
				;;
			esac
		fi
	done < "$1"
}

parseArgs() { #Amazing new argument parsing!!!
	longArg() { #Creates VAL
		ret="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
	}
	while getopts "vh C: o: P: T:  i t: m p: s: k r:  d: f H: c: n: N: Q: O: g: G:  w: A: l: S:  D u b a: F: R:  q K: Y M    -:" opt; do
		#~ echo $opt ${OPTARG}
		case "$opt" in
			-) #Long Arguments
				case ${OPTARG} in
					outdir)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						OUTDIR=$val
						;;
					version)
						PROGRAM="version"
						;;
					help)
						PROGRAM="help"
						;;
					config)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						LCONFIG=$val
						;;
					bin-path)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						BIN_PATH=$val
						setPaths #Set all the paths with the new BIN_PATH.
						;;
					dcraw)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						DCRAW="${val}"
						;;
					mlv-dump)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						MLV_DUMP=$val
						;;
					raw-dump)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						RAW_DUMP=$val
						;;
					badpixels)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						MLV_BP=$val
						;;
					cr-hdr)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						CR_HDR=$val
						;;
					srange)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						PYTHON_BAL=$val
						setPaths #Must regen BAL
						;;
					balance)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						PYTHON_SRANGE=$val
						setPaths #Must regen SRANGE
						;;
					python)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						PYTHON=$val
						setPaths #Set all the paths with the new PYTHON.
						;;
					threads)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						THREADS=$val
						;;
						
						
					uncompress)
						isCOMPRESS=false
						;;
						
						
					shallow)
						DEPTH=""
						DEPTH_OUT="-depth 8"
						;;
						
						
					white-speed)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						WHITE_SPD=$val
						;;
					allow-white-clip)
						isScale=true
						;;
						
					*)
						echo "Invalid option: --$OPTARG" >&2
						;;
				esac
				;;
			
			
			v)
				PROGRAM="version"
				;;
			h)
				PROGRAM="help"
				;;
			C)
				LCONFIG=${OPTARG}
				;;
			o)
				OUTDIR=${OPTARG}
				;;
			P)
				BIN_PATH=${OPTARG}
				setPaths #Set all the binary paths with the new BIN_PATH.
				;;
			T)
				THREADS=${OPTARG}
				;;
				
			
			i)
				IMAGES=true
				;;
			t)
				mode=${OPTARG}
				case ${mode} in
					"0") IMG_FMT="exr"
					;;
					"1") IMG_FMT="tiff"
					;;
					"2") IMG_FMT="png"
					;;
					"3") IMG_FMT="dpx"
					;;
					*) invOption "t: Invalid Image Format Choice: ${mode}"
					;;
				esac
				;;
			m)
				MOVIE=true
				;;
			p)
				PROXY=${OPTARG}
				case ${PROXY} in
					"0") isJPG=false; isH264=false
					;;
					"1") isJPG=false; isH264=true
					;;
					"2") isJPG=true; isH264=false
					;;
					"3") isJPG=true; isH264=true
					;;
					*) invOption "p: Invalid Proxy Choice: ${PROXY}"
					;;
				esac
				;;
			s)
				PROXY_SCALE=${OPTARG}
				
				proxy_num=`echo "$PROXY_SCALE" | cut -d'%' -f 1`
				if [[ ! ( ($proxy_num -le 100 && $proxy_num -ge 5) && $proxy_num =~ ^-?[0-9]+$ ) ]]; then invOption "s: Invalid Proxy Scale: ${PROXY_SCALE}"; fi
				;;
			k)
				KEEP_DNGS=true
				;;
			r)
				RANGE_BASE=${OPTARG}
				isFR=false
				;;
				
			
			d)
				DEMO_MODE=${OPTARG}
				;;
			f)
				FOUR_COLOR="-f"
				;;
			H)
				HIGHLIGHT_MODE=${OPTARG}
				;;
			c)
				mode=${OPTARG}
				case ${mode} in
					"0") CHROMA_SMOOTH="--no-cs"
					;;
					"1") CHROMA_SMOOTH="--cs2x2"
					;;
					"2") CHROMA_SMOOTH="--cs3x3"
					;;
					"3") CHROMA_SMOOTH="--cs5x5"
					;;
					*) invOption "c: Invalid Chroma Smoothing Choice: ${mode}"
					;;
				esac
				;;
			n)
				WAVE_NOISE="-n ${OPTARG}"
				;;
			N)
				vals=${OPTARG}
					
				aVal=$(echo "${vals}" | cut -d"-" -f1)
				bVal=$(echo "${vals}" | cut -d"-" -f2)
				
				TEMP_NOISE="atadenoise=0a=${aVal}:0b=${bVal}:1a=${aVal}:1b=${bVal}:2a=${aVal}:2b=${bVal}"
				tempDesc="Temporal Denoiser"
				FFMPEG_FILTERS=true
				;;
			Q)
				vals=${OPTARG}
				
				S=`echo "${vals}" | cut -d$':' -f1`
				T=`echo "${vals}" | cut -d$':' -f2`
				
				LS=`echo "${S}" | cut -d$'-' -f1`
				CS=`echo "${S}" | cut -d$'-' -f2`
				LT=`echo "${T}" | cut -d$'-' -f1`
				CT=`echo "${T}" | cut -d$'-' -f2`
				
				HQ_NOISE="hqdn3d=luma_spatial=${LS}:chroma_spatial=${CS}:luma_tmp=${LT}:chroma_tmp=${CT}"
				hqDesc="3D Denoiser"
				FFMPEG_FILTERS=true
				;;
			O)
				vals=${OPTARG}
					
				m1=`echo "${vals}" | cut -d$'-' -f1`
				m2=`echo "${vals}" | cut -d$'-' -f2`
				m3=`echo "${vals}" | cut -d$'-' -f3`
				m4=`echo "${vals}" | cut -d$'-' -f4`
				
				REM_NOISE="removegrain=m0=${m1}:m1=${m2}:m2=${m3}:m3=${m4}"
				remDesc="RemoveGrain Modal Denoiser"
				FFMPEG_FILTERS=true
				;;
			g)
				mode=${OPTARG}
				
				case ${mode} in
					"0")
						COLOR_GAMMA="STANDARD" #Lets CM know that it should correspond to the gamut, or be 2.2.
					;;
					"1")
						COLOR_GAMMA="lin" #Linear
					;;
					"2")
						COLOR_GAMMA="cineon" #Cineon
					;;
					"3")
						COLOR_GAMMA="clog2" #C-Log2. Req: color-ext.
					;;
					"4")
						COLOR_GAMMA="slog3" #S-Log3. Req: color-ext.
					;;
					#~ "5")
						#~ COLOR_GAMMA="logc" #LogC 4.X . Req: color-ext.
					#~ ;;
					#~ "6")
						#~ COLOR_GAMMA="acescc" #ACEScc Log Gamma. Req: color-aces.
					#~ ;;
					*)
						invOption "g: Invalid Gamma Choice: ${mode}"
					;;
				esac
				;;
			G)
				mode=${OPTARG}
				
				case ${mode} in
					"0")
						COLOR_GAMUT="srgb" #sRGB
					;;
					"1")
						COLOR_GAMUT="argb" #Adobe RGB
					;;
					"2")
						COLOR_GAMUT="rec709" #Rec.709
					;;
					"3")
						COLOR_GAMUT="xyz" #XYZ. Linear Only.
					;;
					#~ "4")
						#~ COLOR_GAMUT="aces" #ACES. Standard is Linear. Req: color-aces (all gammas will work, even without color-ext)/
					#~ ;;
					"4")
						COLOR_GAMUT="rec2020" #Rec.2020. Req: color-ext.
					;;
					"5")
						COLOR_GAMUT="dcip3" #DCI-P3. Req: color-ext.
					;;
					"6")
						COLOR_GAMUT="ssg3c" #Sony S-Gamut3.cine. Req: color-ext.
					;;
					*)
						invOption "G: Invalid Gamut Choice: ${mode}"
					;;
				esac
				;;
			
			w)
				mode=${OPTARG}
				
				case ${mode} in
					"0") CAMERA_WB=false; GEN_WHITE=true #Will generate white balance.
					;;
					"1") CAMERA_WB=true; GEN_WHITE=false; #Will use camera white balance.
					;;
					"2") WHITE="-r 1 1 1 1"; CAMERA_WB=false; GEN_WHITE=false #Will not apply any white balance.
					;;
					*)
						invOption "w: Invalid White Balance Choice: ${mode}"
					;;
				esac
				;;
			A)
				val=${OPTARG}
				
				lSize=`echo "${val}" | cut -d$':' -f1`
				lStr=`echo "${val}" | cut -d$':' -f2`
				cSize=`echo "${val}" | cut -d$':' -f3`
				cStr=`echo "${val}" | cut -d$':' -f4`
				
				SHARP="unsharp=${lSize}:${lSize}:${lStr}:${cSize}:${cSize}:${cStr}"
				sharpDesc="Sharpen/Blur"
				FFMPEG_FILTERS=true
				;;
			l)
				LUT_PATH=${OPTARG}
				
				if [ ! -f $LUT_PATH ]; then invOption "Invalid LUT Path: ${LUT_PATH}"; fi
				
				#Check LUT_SIZE
				i=0
				while read line; do
					sLine=$(echo $line | sed -e 's/^[ \t]*//')
					if [[ $(echo $sLine | cut -c1-11) == "LUT_3D_SIZE" ]]; then
						if [[ $(echo $sLine | cut -c13-) -le 64 && $(echo $sLine | cut -c13-) -ge 2 ]]; then
							break
						else
							size=$(echo $sLine | cut -c13-)
							invOption "$(basename $LUT_PATH): Invalid LUT Size of $size x $size x $size - Must be between x2 and x64 (you can resize using pylut - see 'convmlv -h') ! "
						fi
					elif [[ $i -gt 20 ]]; then
						invOption "$(basename $LUT_PATH): Invalid LUT - LUT_3D_SIZE not found in first 20 non-commented lines."
					fi
					
					if [[ ! $(echo $sLine | cut -c1-1) == "#" ]]; then ((i++)); fi
				done < $LUT_PATH
				
				LUTS+=( "lut3d=${LUT_PATH}" )
				lutDesc="3D LUTs"
				FFMPEG_FILTERS=true
				;;
			S)
				SATPOINT="-S ${OPTARG}"
				;;
			
			
			D)
				DESHAKE="deshake"
				deshakeDesc="Deshake Filter"
				FFMPEG_FILTERS=true
				;;
			
			u)
				DUAL_ISO=true
				;;
			b)
				isBP=true
				;;
			a)
				BADPIXEL_PATH=${OPTARG}
				BADPIXEL_PATH=${OPTARG}
				;;
			F)
				DARKFRAME=`echo "${line}" | cut -d$' ' -f2`;
					
				if [ ! -f $DARKFRAME ]; then invOption "F: Invalid Darkframe: ${DARKFRAME}"; fi
					
				useDF=true
				;;
			R)
				PROGRAM="darkframe"
				#~ MK_DARK=true
				DARK_OUT=${OPTARG}
				;;
			
			
			q)
				PROGRAM="settings"
				#~ SETTINGS_OUTPUT=true
				;;
			K)
				mode=${OPTARG}

				case ${mode} in
					"0") echo $DEB_DEPS
					;;
					"1") echo $UBU_DEPS
					;;
					"2") echo $FED_DEPS
					;;
					"3") echo $BREW_DEPS
					;;
					*)
						invOption "K: Invalid Dist Choice: ${mode}"
					;;
				esac
				
				exit 0
				;;
			Y)
				echo $PIP_DEPS
				exit 0
				;;
			M)
				echo $MAN_DEPS
				exit 0
				;;
			
			
			*)
				echo "Invalid option: -$OPTARG" >&2
				;;
		esac
	done
}


parseAll() {
	#Big parse/reparse, making sure global, local, command line options all override each other correctly.
	set -- $INPUT_ARGS #Reset the argument input for reparsing.
	setDefaults #Hard set/reset all the lovely globals.
	OPTIND=1 #Reset argument parsing.
	
	parseConf "$GCONFIG" false #Parse global config file.

	parseArgs "$@" #First, parse all cli args. We only need the -C flag, but that forces us to just parse everything.
	shift $((OPTIND-1)) #Shift past all of the options to the file arguments.

	parseConf "$LCONFIG" false #Parse local config file.
	set -- $INPUT_ARGS #Reset $@ for cli option reparsing.
	OPTIND=1 #To reset argument parsing, we must set OPTIND to 1.

	parseArgs "$@" #Reparse cli to overwrite local config options.
	shift $((OPTIND-1)) #Shift past all of the options to the file arguments.
	OPTIND=1 #Reset argument index.
}
