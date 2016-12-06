setRange() {
	#FRAMES must be set at this point.
	if [[ $isFR == true ]]; then #Ensure that FRAME_RANGE is set with $FRAMES.
		FRAME_RANGE="1-${FRAMES}"
		FRAME_START="1"
		FRAME_END=$FRAMES
	else
		base=$(echo $RANGE_BASE | sed -e 's:s:0:g' | sed -e "s:e:$(echo "$FRAMES - 1" | bc):g") #FRAMES is incremented in a moment.
		
		#~ FRAME_RANGE_ZERO="$(echo $base | cut -d"-" -f1)-$(echo $base | cut -d"-" -f2)" #Number from 0. Useless as of now.
		FRAME_RANGE="$(echo "$(echo $base | cut -d"-" -f1) + 1" | bc)-$(echo "$(echo $base | cut -d"-" -f2) + 1" | bc)" #Number from 1.
		FRAME_START=$(echo ${FRAME_RANGE} | cut -d"-" -f1)
		FRAME_END=$(echo ${FRAME_RANGE} | cut -d"-" -f2)
		
		#Some error checking - out of range values default to start and end.
		
		if [[ $FRAME_END -gt $FRAMES || $FRAME_END -lt $FRAME_START || $FRAME_END -lt 1 ]]; then FRAME_END=$FRAMES; fi
		if [[ $FRAME_START -lt 1 || $FRAME_START -gt $FRAME_END ]]; then FRAME_START=1; fi
		
		FRAME_RANGE="${FRAME_START}-${FRAME_END}"
	fi
}

develop() {
	trap "rm -rf ${TMP}; exit 1" INT #TMP will be removed if you CTRL+C.
	for ARG in "${FILE_ARGS_ARRAY[@]}"; do #Go through FILE_ARGS_ARRAY array, copied from parsed $@ because $@ is going to be changing on 'set --'
		ARG=$(readlinkF "$ARG") #Use platform-independent readline.
		
	#The Very Basics
		BASE="$(basename "$ARG")"
		EXT="${BASE##*.}"
		if [[ "${EXT}" == ".${BASE}" ]]; then EXT=""; fi #This means the input is a folder, which has no extension.
		DIRNAME=$(dirname "$ARG")
		TRUNC_ARG="${BASE%.*}"
		SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor for halved video, *2 for 50%
		setBL=true
	#Evaluate local configuration file for file-specific blocks.
		parseConf "$LCONFIG" true
		
	#Check that ARG exists and works.
		local action=$(checkArg)
		if [[ $action = "skip" ]]; then
			let ARGNUM--; continue
		fi
		
	#Color Management - The Color LUT is chosen + applied.

		#We define what "STANDARD" means. Gamma 2.2 if it's not specifically defined.
		if [[ $COLOR_GAMUT != "xyz" ]]; then
		
			#~ if [[ $COLOR_GAMUT == "aces" ]]; then #List of Linear Only gamuts. XYZ excluded, in that that's default output; no filtering needed.
				#~ COLOR_GAMMA="lin"
			#~ fi
		
			if [[ $COLOR_GAMMA == "STANDARD" ]]; then
				if [[ $COLOR_GAMUT == "argb" || $COLOR_GAMUT == "ssg3c" ]]; then #List of gamuts with Gamma 2.2 .
					COLOR_GAMMA="y2*2"
				else
					COLOR_GAMMA=$COLOR_GAMUT
				fi
			fi
			
			for source in "${COLOR_LUTS[@]}"; do
				colorName="${source}/lin_xyz--${COLOR_GAMMA}_${COLOR_GAMUT}.cube"
				if [[ -f $colorName ]]; then
					COLOR_VF="lut3d=$colorName"
					colorDesc="Color Management LUT"
					FFMPEG_FILTERS=true
				fi
			done
			
			if [[ $COLOR_VF == "" ]]; then
				echo -e "\033[0;31m\033[1mSpecified LUT not found! Is color-ext loaded?.\033[0m\n"
			fi
				
		fi #COLOR_VF is nothing if the gamut is xyz - it'll pass directly out of dcraw/IM, without LUT application.
		
	#Construct the FFMPEG filters.
		FINAL_SCALE="scale=trunc(iw/2)*${SCALE}:trunc(ih/2)*${SCALE}"
		if [[ $FFMPEG_FILTERS == true ]]; then
			V_FILTERS="-vf $(joinArgs , ${COLOR_VF} ${LUTS[@]} ${HQ_NOISE} ${TEMP_NOISE} ${REM_NOISE} ${SHARP} ${DESHAKE})"
			V_FILTERS_PROX="-vf $(joinArgs , ${COLOR_VF} ${LUTS[@]} ${HQ_NOISE} ${TEMP_NOISE} ${REM_NOISE} ${SHARP} ${DESHAKE} ${FINAL_SCALE})" #Proxy filter set adds the FINAL_SCALE component.
			
			#Created formatted array of filters, FILTER_ARR.
			compFilters=()
			declare -a compFilters=("${colorDesc}" "${sharpDesc}" "${hqDesc}" "${tempDesc}" "${remDesc}" "${deshakeDesc}" "${lutDesc}")
			for v in "${compFilters[@]}"; do if test "$v"; then FILTER_ARR+=("$v"); fi; done
		else
			V_FILTERS_PROX="-vf ${FINAL_SCALE}"
		fi
		
	#List remaining files to process.
		remFiles=${@:`echo "$# - ($ARGNUM - 1)" | bc`:$#}
		remArr=$(echo $remFiles)
		
		list=""
		for item in $remArr; do
			itemBase=$(basename $item)
			itemExt=".${itemBase##*.}" #Dot must be in here.
			if [[ "${itemExt}" == ".${itemBase}" ]]; then itemExt=""; fi #This means the input is a folder, which has no extension.
			itemDir=$(dirname "$item")
			
			if [ -z "${list}" ]; then
				if [[ $itemBase == $(basename $ARG) ]]; then
					list="${itemDir}/\033[1m\033[32m${itemBase%.*}\033[0m${itemExt}"
				else
					list="${itemDir}/\033[1m${itemBase%.*}\033[0m${itemExt}"
				fi
			else
				list="${list}, ${itemDir}/\033[1m${itemBase%.*}\033[0m${itemExt}"
			fi
		done
		
		if [ $ARGNUM == 1 ]; then
			echo -e "\n\033[1m${ARGNUM} File Left to Process:\033[0m ${list}\n"
		else
			echo -e "\n\033[1m${ARGNUM} Files Left to Process:\033[0m ${list}\n"
		fi

	#PREPARATION

	#Establish Basic Directory Structure.
		OUTDIR=$(readlinkF "$OUTDIR")
		
		if [ $OUTDIR != $PWD ] && [ $isOutGen == false ]; then
			mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP ad-hoc HALD LUT implementation :'( .
			isOutGen=true
		fi
		
		FILE="${OUTDIR}/${TRUNC_ARG}"
		TMP="${FILE}/tmp_${TRUNC_ARG}"
		
	#DNG argument, reused or not. Also, create FILE and TMP.
		DEVELOP=true
		if [[ ( -d $ARG ) && ( ( `basename ${ARG} | cut -c1-3` == "dng" && -f "${ARG}/../settings.txt" ) || ( `basename ${ARG}` == $TRUNC_ARG && -f "${ARG}/settings.txt" ) ) ]]; then #If we're reusing a dng sequence, copy over before we delete the original.
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Moving DNGs from previous run...\n" #Use prespecified DNG sequence.
			
			#User may specify either the dng_ or the trunc_arg folder; must account for both.
			if [[ `folderName ${ARG}` == $TRUNC_ARG && -d "${ARG}/dng_${TRUNC_ARG}" ]]; then #Accounts for the trunc_arg folder.
				ARG="${ARG}/dng_${TRUNC_ARG}" #Set arg to the dng argument.
			elif [[ `folderName ${ARG}` == $TRUNC_ARG && `echo "$(basename ${ARG})" | cut -c 1-3` == "dng" ]]; then #Accounts for the dng_ folder.
				TRUNC_ARG=`echo $TRUNC_ARG | cut -c5-${#TRUNC_ARG}`
			else
				echo -e "\033[0;31m\033[1mCannot reuse - DNG folder does not exist! Skipping argument.\033[0m"
				continue
			fi
			
			DNG_LOC=${OUTDIR}/tmp_reused
			mkdir -p ${OUTDIR}/tmp_reused
			
			find $ARG -iname "*.dng" | xargs -I {} mv {} $DNG_LOC #Copying DNGs to temporary location.
			
			dngSet "$DNG_LOC"
			FPS=`cat ${ARG}/../settings.txt | grep "FPS" | cut -d $" " -f2` #Grab FPS from previous run.
			FRAMES=`cat ${ARG}/../settings.txt | grep "Frames" | cut -d $" " -f2` #Grab FRAMES from previous run.
			KELVIN=`cat ${ARG}/../settings.txt | grep "WBKelvin" | cut -d $" " -f2`
			cp "${ARG}/../settings.txt" $DNG_LOC
			
			oldARG="${ARG}"
			DIRNAME=$(dirname "$oldARG")
			BASE="$(basename "$oldARG")"
			EXT=""
			
			FILE="${OUTDIR}/${TRUNC_ARG}"
			TMP="${FILE}/tmp_${TRUNC_ARG}" #Remove dng_ from ARG by redefining basic constants. Ready to go!
			ARG="${FILE}/dng_${TRUNC_ARG}" #Careful. This won't exist till later.
			
			
			dngLocClean() {
				find $DNG_LOC -iname "*.dng" | xargs -I {} mv {} $oldARG
				rm -rf $DNG_LOC
			}
			
			mkdirS $FILE dngLocClean
			mkdirS $TMP #Make the folders.
			
			find $DNG_LOC -iname "*.dng" | xargs -I {} mv {} $TMP #Moving files to where they need to go.
			cp "${DNG_LOC}/settings.txt" $FILE
					
			setBL=false
			DEVELOP=false
			rm -r $DNG_LOC
		elif [ -d $ARG ]; then #If it's a DNG sequence, but not a reused one.
			mkdirS $FILE
			mkdirS $TMP
			
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Using specified folder of RAW sequences...\n" #Use prespecified DNG sequence.
			
			FPS=24 #Set it to a safe default.
			FRAMES=$(find ${ARG} -name "*.dng" | wc -l)
			
			setRange
			
			i=1
			for dng in $ARG/*.dng; do
				ln -s $dng $(printf "${TMP}/${TRUNC_ARG}_%06d.dng" $i) #Since we're not touching the DNGs, we can link them from wherever to TMP!!! :) Super duper fast.
				let i++
				if [[ i -gt $FRAME_END ]]; then break; fi
			done
			
			dngSet
			
			DEVELOP=false #We're not developing DNG's; we already have them!
		else
			mkdirS $FILE
			mkdirS $TMP
		fi
		
	#Darkframe Averaging
		if [[ $useDF == true ]]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Creating darkframe for subtraction...\n"
			
			avgFrame="${TMP}/avg.darkframe" #The path to the averaged darkframe file.
			
			#~ There was a bug - retest this.
			darkBase="$(basename "$DARKFRAME")"
			darkExt="${darkBase##*.}"
			
			if [ $darkExt != 'darkframe' ]; then
				$MLV_DUMP -o "${avgFrame}" -a $DARKFRAME >/dev/null 2>/dev/null
			else
				cp $DARKFRAME $avgFrame #Copy the preaveraged frame if the extension is .darkframe.
			fi
			
			RES_DARK=`echo "$(${MLV_DUMP} -v -m ${avgFrame})" | grep "Res" | sed 's/[[:alpha:] ]*:  //'`
			
			DARK_PROC="-s ${avgFrame}"
		fi

	#Develop sequence if needed.
		if [ $DEVELOP == true ]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Dumping to DNG Sequence...\n"
					
			if [ ! $DARKFRAME == "" ] && [ ! $CHROMA_SMOOTH == "--no-cs" ]; then #Just to let the user know that certain features are impossible with RAW.
				rawStat="*Skipping Darkframe subtraction and Chroma Smoothing for RAW file ${TRUNC_ARG}."
			elif [ ! $DARKFRAME == "" ]; then
				rawStat="*Skipping Darkframe subtraction for RAW file ${TRUNC_ARG}."
			elif [ ! $CHROMA_SMOOTH == "--no-cs" ]; then
				rawStat="*Skipping Chroma Smoothing for RAW file ${TRUNC_ARG}."
			else
				rawStat="\c"
			fi
			
			#IF extension is RAW, we want to convert to MLV. All the interesting features are MLV-only, because of mlv_dump's amazingness.
			
			if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
				# Read the header.
				mlvSet
				setRange
				
				# Error checking: Darkframe resolution must match resolution.
				if [[ (! -z $RES_DARK) && $RES_DARK != $RES_IN ]]; then
					invOption "Darkframe Resolution doesn't match MLV Resolution! Use another darkframe!"
				fi
				
				#Dual ISO might want to do the chroma smoothing. In which case, don't do it now!
				if [ $DUAL_ISO == true ]; then
					smooth="--no-cs"
				else
					smooth=$CHROMA_SMOOTH
				fi
				
				#Create new MLV with adequate number of frames, if needed.
				REAL_MLV=$ARG
				REAL_FRAMES=$FRAMES
				if [ $isFR == false ]; then
					REAL_MLV="${TMP}/newer.mlv"
					$MLV_DUMP $ARG -o ${REAL_MLV} -f ${FRAME_RANGE} >/dev/null 2>/dev/null
					REAL_FRAMES=`${MLV_DUMP} ${REAL_MLV} | awk '/Processed/ { print $2; }'`
				fi
				
				fileRanges=(`echo $($SRANGE $REAL_FRAMES $THREADS)`) #Get an array of frame ranges from the amount of frames and threads. I used a python script for this.
				#Looks like this: 0-1 2-2 3-4 5-5 6-7 8-8 9-10. Put that in an array.

				devDNG() { #Takes n arguments: 1{}, the frame range 2$MLV_DUMP 3$REAL_MLV 4$DARK_PROC 5$no_data 6$smooth 7$TMP 8$FRAME_END 9$TRUNC_ARG 10$FRAME_START
					range=$1
					firstFrame=false
					if [[ $range == "0-0" ]]; then #mlv_dump can't handle 0-0, so we develop 0-1.
						range="0-1"
						firstFrame=true
					fi
					
					tmpOut=${7}/${range} #Each output will number from 0, so give each its own folder.
					mkdir -p $tmpOut
					
					start=$(echo "$range" | cut -d'-' -f1)
					end=$(echo "$range" | cut -d'-' -f2) #Get start and end frames from the frame range
					
					$2 $3 $4 -o "${tmpOut}/${9}_" -f ${range} $6 --dng --batch | { #mlv_dump command. Uses frame range.
						lastCur=0
						while IFS= read -r line; do
							output=$(echo $line | grep -Po 'V.*A' | cut -d':' -f2 | cut -d$' ' -f1) #Hacked my way to the important bit.
							if [[ $output == "" ]]; then continue; fi #If there's no important bit, don't print.
							
							cur=$(echo "$output" | cut -d'/' -f1) #Current frame.
							if [[ $cur == $lastCur ]] || [[ $cur -gt $end ]] || [[ $cur -lt $start ]]; then continue; fi #Turns out, it goes through all the frames, even if cutting the frame range. So, clamp it!
							
							lastCur=$cur #It likes to repeat itself.
							echo -e "\033[2K\rMLV to DNG: Frame $(echo "${cur} + ${10}" | bc)/${8}\c" #Print out beautiful progress bar, in parallel!
						done
						
					} #Progress Bar
					if [[ $firstFrame == true ]]; then #If 0-0.
						rm $(printf "${tmpOut}/${9}_%06d.dng" 1) 2>/dev/null #Remove frame #1, leaving us only with frame #0.
						mv $tmpOut "${7}/0-0" #Move back to 0-0, as if that's how it was developed all along.
					fi
				}
				
				export -f devDNG #Export to run in subshell.
				
				for range in "${fileRanges[@]}"; do echo $range; done | #For each frame range, assign a thread.
					xargs -I {} -P $THREADS -n 1 \
						bash -c "devDNG '{}' '$MLV_DUMP' '$REAL_MLV' '$DARK_PROC' 'no_data' '$smooth' '$TMP' '$FRAME_END' '$TRUNC_ARG' '$FRAME_START'"
				
				#Since devDNG must run in a subshell, globals don't follow. Must pass *everything* in.
				echo -e "\033[2K\rMLV to DNG: Frame ${FRAME_END}/${FRAME_END}\c" #Ensure it looks right at the end.
				echo -e "\n"
				
				count=$FRAME_START
				for range in "${fileRanges[@]}"; do #Go through the subfolders sequentially
					tmpOut=${TMP}/${range} #Use temporary folder. It will be named the same as the frame range.
					for dng in ${tmpOut}/*.dng; do
						if [ $count -gt $FRAME_END ]; then echo "ERROR! Count greater than end!"; fi
						mv $dng $(printf "${TMP}/${TRUNC_ARG}_%06d.dng" $count) #Move dngs out sequentially, numbering them properly.
						let count++
					done
					rm -r $tmpOut #Remove the now empty subfolder
				done
				
			elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
				rawSet
				setRange
				
				echo -e $rawStat
				FPS=`$RAW_DUMP $ARG "${TMP}/${TRUNC_ARG}_" | awk '/FPS/ { print $3; }'` #Run the dump while awking for the FPS.
			fi
					
			#~ BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng)
		fi
		
		setRange #Just to be sure the frame range was set, in case the input isn't MLV.
		
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng) #Use the first DNG to get the correct black level.
		
		prntSet > $FILE/settings.txt
		sed -i -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $FILE/settings.txt #Strip escape sequences.
		
	#Create badpixels file.
		if [ $isBP == true ] && [ $DEVELOP == true ]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Generating badpixels file...\n"
			
			bad_name="badpixels_${TRUNC_ARG}.txt"
			gen_bad="${TMP}/${bad_name}"
			touch $gen_bad
			
			if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
				$MLV_BP -o $gen_bad $ARG
			elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
				$MLV_BP -o $gen_bad $ARG
			fi
			
			if [[ ! -z $BADPIXEL_PATH ]]; then
				if [ -f "${gen_bad}" ]; then
					echo -e "\033[1m${TRUNC_ARG}:\033[0m Concatenating with specified badpixels file...\n"
					mv "${gen_bad}" "${TMP}/bp_gen"
					cp $BADPIXEL_PATH "${TMP}/bp_imp"
					
					{ cat "${TMP}/bp_gen" && cat "${TMP}/bp_imp"; } > "${gen_bad}" #Combine specified file with the generated file.
				else
					cp $BADPIXEL_PATH "${gen_bad}"
				fi
			fi
			
			BADPIXELS="-P ${gen_bad}"
		elif [[ ! -z $BADPIXEL_PATH ]]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Using specified badpixels file...\n"
			
			bad_name="badpixels_${TRUNC_ARG}.txt"
			gen_bad="${TMP}/${bad_name}"
			
			cp $BADPIXEL_PATH "${gen_bad}"
			BADPIXELS="-P ${gen_bad}"
		fi

	#Dual ISO Conversion
		if [ $DUAL_ISO == true ]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Combining Dual ISO...\n"
			
			#Original DNGs will be moved here.
			oldFiles="${TMP}/orig_dng"
			mkdirS $oldFiles
			
			inc_iso() { #6 args: 1{} 2$CR_HDR 3$TMP 4$FRAME_END 5$oldFiles 6$CHROMA_SMOOTH. {} is a path. Progress is thread safe. Experiment gone right :).
				count=$(echo "$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) + 1" | bc) #Get count from filename.
				
				$2 $1 $6 >/dev/null 2>/dev/null #The LQ option, --mean23, is completely unusable in my opinion.
				
				name=$(basename "$1")
				mv "${3}/${name%.*}.dng" $5 #Move away original dngs.
				mv "${3}/${name%.*}.DNG" "${3}/${name%.*}.dng" #Rename *.DNG to *.dng.
				
				echo -e "\033[2K\rDual ISO Development: Frame ${count}/${4}\c"
			}
			
			export -f inc_iso #Must expose function to subprocess.
			
			#~ echo "${CR_HDR} ${TMP}/${TRUNC_ARG}_$(printf "%06d" $FRAME_START).dng"
			if [[ $(${CR_HDR} "${TMP}/${TRUNC_ARG}_$(printf "%06d" $FRAME_START).dng") == *"ISO blending didn't work"* ]]; then
				invOption "The input wasn't shot Dual ISO!"
			fi
			
			find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
				bash -c "inc_iso '{}' '$CR_HDR' '$TMP' '$FRAME_END' '$oldFiles' '$CHROMA_SMOOTH'"
					
			BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng) #Use the first DNG to get the new correct black level.

			echo -e "\n"
		fi
		
		if [ $setBL == true ]; then
			echo -e "BlackLevel: ${BLACK_LEVEL}" >> $FILE/settings.txt #Black level must now be set.
		fi
		
		normToOne() {
			wBal=$1
			
			max=0.0
			for mult in $wBal; do
				if [ $(echo " $mult > $max" | bc) -eq 1 ]; then
					max=$mult
				fi
			done
			
			for mult in $wBal; do
				echo -e "$(echo "scale=6; x=${mult} / ${max}; if(x<1) print 0; x" | bc -l) \c" #BC is bae.
			done
		}
		
		getGreen() {
			wBal=$1
			
			i=0
			for mult in $wBal; do
				if [ $i -eq 1 ]; then
					echo -e "${mult}"
				fi
				let i++
			done
		}
		
	#Get White Balance correction factor.
		if [ $GEN_WHITE == true ]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Generating WB...\n"
			
			#Calculate n, the distance between samples.
			frameLen=$(echo "$FRAME_END - $FRAME_START + 1" | bc) #Offset by one to avoid division by 0 errors later. min value must be 1.
			
			#A point of improvement, this.
			if [[ $WHITE_SPD -gt $frameLen ]]; then
				WHITE_SPD=$frameLen
			fi
			n=`echo "${frameLen} / ${WHITE_SPD}" | bc`
			
			toBal="${TMP}/toBal"
			mkdirS $toBal
			
			#Develop every nth file for averaging.
			local i=0
			local t=0
			for file in $TMP/*.dng; do 
				if [ `echo "(${i}+1) % ${n}" | bc` -eq 0 ]; then
					$DCRAW -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -k $BLACK_LEVEL $SATPOINT -o 0 -T "${file}"
					name=$(basename "$file")
					mv "$TMP/${name%.*}.tiff" $toBal #TIFF MOVEMENT. We use TIFFs here because it's easy for dcraw and Python.
					let t++
				fi
				echo -e "\033[2K\rWB Development: Sample ${t}/$(echo "${frameLen} / $n" | bc) (Frame: $(echo "${i} + 1" | bc)/${FRAME_END})\c"
				let i++
			done
			echo ""
			
			#Calculate + store result into a form dcraw likes.
			echo -e "Calculating Auto White Balance..."
			BALANCE=`$BAL $toBal`
			
		elif [ $CAMERA_WB == true ]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Retrieving Camera White Balance..."
			
			for file in $TMP/*.dng; do
				#dcraw a single file verbosely, to get the camera multiplier with awk.
				BALANCE=`$DCRAW -T -w -v -c ${file} 2>&1 | awk '/multipliers/ { print $2, $3, $4 }'`
				break
			done

		else #Something must always be set.
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Ignoring White Balance..."
			
			BALANCE="1.000000 1.000000 1.000000"
		fi
		
		#Finally, set the white balance after determining it.
		if [ $isScale = false ]; then
			BALANCE=$(normToOne "$BALANCE")
		fi
		green=$(getGreen "$BALANCE")
		WHITE="-r ${BALANCE} ${green}"
		echo -e "Correction Factor (RGBG): ${BALANCE} ${green}\n"

	#Move .wav.
		SOUND_PATH="${TMP}/${TRUNC_ARG}_.wav"
		
		if [ ! -f $SOUND_PATH ]; then
			echo -e "*Not moving .wav, because it doesn't exist.\n"
		else
			echo -e "*Moving .wav.\n"
			cp $SOUND_PATH $FILE
		fi
		
	#DEFINE PROCESSING FUNCTIONS
		dcrawOpt() { #Find, develop, and splay raw DNG data as ppm, ready to be processed.
			find "${TMP}" -maxdepth 1 -iname "*.dng" -print0 | sort -z | tr -d "\n" | xargs -0 \
				$DCRAW -c -q $DEMO_MODE $FOUR_COLOR -k $BLACK_LEVEL $SATPOINT $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $WAVE_NOISE -o $SPACE $DEPTH
		} #Is prepared to pipe all the files in TMP outwards.
		
		dcrawImg() { #Find and splay image sequence data as ppm, ready to be processed by ffmpeg. Not working well.
			find "${SEQ}" -maxdepth 1 -iname "*.${IMG_FMT}" -print0 | sort -z | xargs -0 -I {} convert '{}' -set colorspace sRGB -colorspace RGB ppm:-
		} #Finds all images, prints to stdout, without any operations, using convert. ppm conversion is inevitably slow, however...
		
		mov_main() {
			ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
				-loglevel panic -stats $SOUND -vcodec prores_ks -pix_fmt rgb48be -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $V_FILTERS $SOUND_ACTION "${VID}_hq.mov"
		} #-loglevel panic -stats
		
		mov_prox() {
			ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
				-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast $V_FILTERS_PROX -crf 23 -c:a mp3 "${VID}_lq.mp4"
		} #The option -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.
		
		mov_main_img() {
			ffmpeg -start_number $FRAME_START -loglevel panic -stats -f image2 -i ${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT} $SOUND -vcodec prores_ks \
				-pix_fmt rgb48le -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $V_FILTERS $SOUND_ACTION "${VID}_hq.mov"
		}
		
		mov_prox_img() {
			ffmpeg -start_number $FRAME_START -loglevel panic -stats -f image2 -i ${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT} $V_FILTERS_PROX $SOUND -c:v libx264 \
				-n -r $FPS -preset veryfast -crf 21 -c:a mp3 -b:a 320k "${VID}_lq.mp4"
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
		
		img_par() { #Takes 22 arguments: {} 2$DEMO_MODE 3$FOUR_COLOR 4$BADPIXELS 5$WHITE 6$HIGHLIGHT_MODE 7$GAMMA 8$WAVE_NOISE 9$DEPTH 10$SEQ 11$TRUNC_ARG 12$IMG_FMT 13$FRAME_END 14$DEPTH_OUT 15$COMPRESS 16$isJPG 17$PROXY_SCALE 18$PROXY 19$BLACK_LEVEL 20$SPACE 21$SATPOINT 22$DCRAW 23$FFMPEG_FILTERS
			count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Instead of count from file, count from name!
			DCRAW=${22}
			
			DPXHACK=""
			if [[ ${12^^} == "DPX" && ( ${23} == false ) ]]; then DPXHACK="-colorspace sRGB"; else DPXHACK=""; fi
			#Trust me, I've tried everything else; but this sRGB transform works. Must be an IM bug. Keep an eye on it!
			#The sRGB curve is only applied if going to DPX while DPX is the target image format. Aka. At the end; not in the middle.
				
			if [ ${16} == true ]; then
				$DCRAW -c -q $2 $3 $4 $5 -H $6 -k ${19} ${21} -g $7 $8 -o ${20} $9 $1 | \
					tee >(convert ${14} - -set colorspace RGB ${DPXHACK} ${15} $(printf "${10}/${11}_%06d.${12}" ${count})) | \
						convert - -set colorspace XYZ -quality 80 -colorspace sRGB -resize ${17} $(printf "${18}/${11}_%06d.jpg" ${count})
						#JPGs don't get ffmpeg filters applied. They simply can't handle it.
				echo -e "\033[2K\rDNG to ${12^^}/JPG: Frame ${count^^}/${13}\c"
			else
				$DCRAW -c -q $2 $3 $4 $5 -H $6 -k ${19} ${21} -g $7 $8 -o ${20} $9 $1 | \
					convert ${14} - -set colorspace RGB ${DPXHACK} ${15} $(printf "${10}/${11}_%06d.${12}" ${count})
				echo -e "\033[2K\rDNG to ${12^^}: Frame ${count^^}/${13}\c"
			fi
		}
	#~ See http://www.imagemagick.org/discourse-server/viewtopic.php?t=21161
		
		export -f img_par
		
		
	#PROCESSING

	#IMAGE PROCESSING
		if [ $IMAGES == true ] ; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Processing Image Sequence from Frame ${FRAME_START} to ${FRAME_END}...\n"
			
	#Define Image Directories, Create SEQ directory
			SEQ="${FILE}/${IMG_FMT}_${TRUNC_ARG}"
			PROXY="${FILE}/proxy_${TRUNC_ARG}"
			
			mkdirS $SEQ
			
			if [ $isJPG == true ]; then
				mkdirS $PROXY
			fi
			
	#Define hardcoded compression based on IMG_FMT
			if [ $isCOMPRESS == true ]; then
				if [ $IMG_FMT == "exr" ]; then
					COMPRESS="-compress piz"
				elif [ $IMG_FMT == "tiff" ]; then
					COMPRESS="-compress zip"
				elif [ $IMG_FMT == "png" ]; then
					COMPRESS="-quality 0"
				elif [ $IMG_FMT == "dpx" ]; then
					COMPRESS="-compress rle"
				fi
			fi

	#Convert all the actual DNGs to IMG_FMT, in parallel.
			find "${TMP}" -maxdepth 1 -name '*.dng' -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
				bash -c "img_par '{}' '$DEMO_MODE' '$FOUR_COLOR' '$BADPIXELS' '$WHITE' '$HIGHLIGHT_MODE' '$GAMMA' '$WAVE_NOISE' '$DEPTH' \
				'$SEQ' '$TRUNC_ARG' '$IMG_FMT' '$FRAME_END' '$DEPTH_OUT' '$COMPRESS' '$isJPG' '$PROXY_SCALE' '$PROXY' '$BLACK_LEVEL' '$SPACE' '$SATPOINT' '$DCRAW' '$FFMPEG_FILTERS'"
			
			# Removed  | cut -d '' -f $FRAME_RANGE , as this happens when creating the DNGs in the first place.

			if [ $isJPG == true ]; then #Make it print "Frame $FRAMES / $FRAMES" as the last output :).
				echo -e "\033[2K\rDNG to ${IMG_FMT^^}/JPG: Frame ${FRAME_END}/${FRAME_END}\c"
			else
				echo -e "\033[2K\rDNG to ${IMG_FMT^^}: Frame ${FRAME_END}/${FRAME_END}\c"
			fi
			
			echo -e "\n"
			
			tConvert() { #Arguments: 1$inFolder 2$outFolder 3$fromFMT 4$toFMT
				inFolder=$1
				outFolder=$2
				fromFMT=$3
				toFMT=$4
				iccProf=$5
				
				if [[ ! -z $iccProf ]]; then iccProf="+profile icm -profile $iccProf"; fi
				
				conv_par() { # Arguments: 1${} 2$TRUNC_ARG 3$outFolder 4$fromFMT 5$iccProf 6$toFMT 7$DEPTH_OUT 8$compress 9$FRAME_END 10$IMG_FMT
					count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Get count from filename.
					
					echo -e "\033[2K\rMiddle-step: ${4^^} to ${6^^}, Frame ${count^^}/${9}\c"
					
					DPXHACK=""
					if [[ ${6^^} == "DPX" && ${10^^} == ${6^^} ]]; then DPXHACK="-colorspace sRGB"; else DPXHACK=""; fi
					#Trust me, I've tried everything else; but this sRGB transform works. Must be an IM bug. Keep an eye on it!
					#The sRGB curve is only applied if going to DPX while DPX is the target image format. Aka. At the end; not in the middle.
					
					convert ${7} ${1} ${5} $8 -set colorspace RGB ${DPXHACK} "${3}/$(printf "${2}_%06d" ${count}).${6}"
				}
				
				export -f conv_par
				
				compress=""
				if [[ ${IMG_FMT^^} == ${toFMT^^} ]]; then compress=${COMPRESS}; fi
				
				find $inFolder -iname "*.${fromFMT}" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
					bash -c "conv_par '{}' '$TRUNC_ARG' '$outFolder' '$fromFMT' '$iccProf' '$toFMT' '$DEPTH_OUT' '$compress' '$FRAME_END' '$IMG_FMT'"
				
				echo ""
			}
			
	#FFMPEG Filter Application: Temporal Denoising, 3D LUTs, Deshake, hqdn Denoising, removegrain denoising, unsharp so far.
	#See construction of $V_FILTERS in PREPARATION.
			if [[ $FFMPEG_FILTERS == true ]]; then
				tmpFiltered="${TMP}/filtered"
				tmpUnfiltered="${TMP}/unfiltered"
				mkdir $tmpFiltered
				mkdir $tmpUnfiltered
				
				#Give correct output.
				echo -e "\033[1mApplying Filters:\033[0m $(joinArgs ", " "${FILTER_ARR[@]}")...\n"
				
				applyFilters() { #Ideally, this would be all we need. But alas, ffmpeg + exr is broken.
					IO=$1
					FMT=$2
					
					if [[ -z $FMT ]]; then FMT="${IMG_FMT}"; fi
					
					ffmpeg -start_number $FRAME_START -f image2 -i "${IO}/${TRUNC_ARG}_%06d.${FMT}" -loglevel panic -stats $V_FILTERS \
						-pix_fmt rgb48be -start_number $FRAME_START "${tmpFiltered}/${TRUNC_ARG}_%06d.${FMT}"
					
					tConvert "$tmpFiltered" "$IO" "$FMT" "$FMT" # "/home/sofus/subhome/src/convmlv/color/lin_xyz--srgb_srgb.icc" - profile application didn't work...
				}
				
				if [[ $IMG_FMT == "exr" ]]; then
					echo -e "Note: EXR filtering lags due to middle-step conversion (ffmpeg has no EXR encoder).\n"
					
					img_res=$(identify ${SEQ}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).${IMG_FMT} | cut -d$' ' -f3)
					
					tConvert "$SEQ" "$tmpUnfiltered" "$IMG_FMT" "dpx"
					
					ffmpeg -start_number $FRAME_START -f image2 -vcodec dpx -s "${img_res}" -r $FPS -loglevel panic -stats -i "${tmpUnfiltered}/${TRUNC_ARG}_%06d.dpx" \
						$V_FILTERS -pix_fmt rgb48be -vcodec dpx -n -r $FPS -start_number $FRAME_START ${tmpFiltered}/${TRUNC_ARG}_%06d.dpx
						
					tConvert "$tmpFiltered" "$SEQ" "dpx" "$IMG_FMT"
				else
					applyFilters "$SEQ"
				fi
							
				echo ""
			fi
		fi
			
	#MOVIE PROCESSING
		VID="${FILE}/${TRUNC_ARG}"
		
		SOUND="-i ${TMP}/${TRUNC_ARG}_.wav"
		SOUND_ACTION="-c:a mp3 -b:a 320k"
		if [ ! -f $SOUND_PATH ]; then
			SOUND=""
			SOUND_ACTION=""
		fi
			
		if [[ $MOVIE == true && $IMAGES == false && $isH264 == true ]]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to ProRes/H.264..."
			runSim dcrawOpt mov_main mov_prox
			echo ""
		elif [[ $MOVIE == true && $IMAGES == false && $isH264 == false ]]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to ProRes..."
			dcrawOpt | mov_main
			echo ""
		elif [[ $MOVIE == false && $IMAGES == false && $isH264 == true ]]; then
			echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to H.264..."
			dcrawOpt | mov_prox
			echo ""
		elif [[ $IMAGES == true ]]; then
			V_FILTERS="" #Only needed if reading from images.
			V_FILTERS_PROX="-vf $FINAL_SCALE"
			
			if [[ $IMG_FMT == "dpx" ]]; then
				V_FILTERS="-vf lut3d=${COLOR_LUTS[0]}/srgb--lin.cube"
				V_FILTERS_PROX="-vf lut3d=${COLOR_LUTS[0]}/srgb--lin.cube,$FINAL_SCALE" #We apply a sRGB to Linear 1D LUT if reading DPX. Because it's fucking broken.
			fi
			
			#Use images if available, as opposed to developing the files again.
			if [[ $MOVIE == true && $isH264 == true ]]; then
				echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to ProRes/H.264..."
				mov_main_img &
				mov_prox_img &
				wait
				
				echo ""
			elif [[ $MOVIE == true && $isH264 == false ]]; then
				echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to ProRes..."
				mov_main_img
				echo ""	
			elif [[ $MOVIE == false && $isH264 == true ]]; then
				echo -e "\033[1m${TRUNC_ARG}:\033[0m Encoding to H.264..."
				mov_prox_img
				echo ""
			fi
		fi
		
	#Potentially move DNGs.
		if [ $KEEP_DNGS == true ]; then
			echo -e "\033[1mMoving DNGs...\033[0m"
			DNG="${FILE}/dng_${TRUNC_ARG}"
			mkdirS $DNG
			
			if [ $DUAL_ISO == true ]; then
				oldFiles="${TMP}/orig_dng"
				find $oldFiles -name "*.dng" | xargs -I '{}' mv {} $DNG #Preserve the original, unprocessed DNGs.
			else
				find $TMP -name "*.dng" | xargs -I '{}' mv {} $DNG
			fi
		fi
		
		echo -e "\n\033[1mCleaning Up.\033[0m\n\n"
		
	#Delete tmp
		rm -rf $TMP
		
	#RESET ARGS & REPARSE OPTIONS - same as in convmlv.sh.
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
		
		let ARGNUM--
	done
}
