setRange() {
	#FRAMES must be set at this point.
	#usage: setRange
	#desc: Using FRAMES, sets the variables pertaining to frame range.
	
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
	#Usage: develop arg  -- globals are treated as a large, passed in data structure.
	#Desc: Develops footage according to the current configuration of global variables.
		
	local ARG=$(readlinkF "$1") #ARG is the MLV, RAW, or DNG sequence to be processed.
	
	local DIRNAME=$(dirname "$ARG") #DIRNAME is the name of the folder containing the ARG.
	
#The Very Basics
	local BASE="$(basename "$ARG")" #BASE is the name of the file.
	local TRUNC_ARG="${BASE%.*}" #TRUNC_ARG is the name of the file, sans extension.
	
	local EXT="${BASE##*.}" #EXT is the file's extension.
	if [[ "${EXT}" == ".${BASE}" ]]; then EXT=""; fi #If the input is a folder, it will have no extension.
	
	local SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor for halved video, *2 for 50%
	setBL=true
	
#Color Management - The Color LUT is chosen + applied.

	#We define what "STANDARD" means. Gamma 2.2 if it's not specifically defined.
	if [[ $COLOR_GAMUT != "xyz" ]]; then
	
		#This block defines what a "STANDARD" gamma means for each gamut.
		if [[ $COLOR_GAMMA == "STANDARD" ]]; then
			if [[ $COLOR_GAMUT == "argb" || $COLOR_GAMUT == "ssg3c" ]]; then #List of gamuts with Gamma 2.2 .
				COLOR_GAMMA="y2*2"
			elif [[ $COLOR_GAMUT == "aces" ]]; then #ACES is linear.
				COLOR_GAMMA="lin"
			else
				COLOR_GAMMA=$COLOR_GAMUT #Otherwise, "standard" is the name of the gamut.
			fi
		fi
		
		for lutSource in "${COLOR_LUTS[@]}"; do
			colorName="${lutSource}/lin_xyz--${COLOR_GAMMA}_${COLOR_GAMUT}.cube"
			#~ colorName="${lutSource}/lin_srgb--${COLOR_GAMMA}_${COLOR_GAMUT}.cube"
			if [[ -f $colorName ]]; then
				COLOR_VF="lut3d=$colorName"
				colorDesc="Color Management LUT"
				FFMPEG_FILTERS=true
			fi
		done
		
		if [[ $COLOR_VF == "" ]]; then
			error "Specified LUT not found! Is color-ext loaded?\n"
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
	local remFiles=("${FILE_ARGS_ARRAY[@]:$ARG_INC:$ARGNUM}") #Make a new array from slice.
	
	#Assemble list of files left to process.
	list=""
	for item in "${remFiles[@]}"; do
		local itemBase=$(basename $item)
		local itemExt=".${itemBase##*.}" #Dot must be in here.
		if [[ "${itemExt}" == ".${itemBase}" ]]; then itemExt=""; fi #This means the input is a folder, which has no extension.
		
		local itemDir=$(dirname "$item")
		
		if [ -z "${list}" ]; then
			list=$(formArg "$ARG" "selected")
			#~ if [[ $itemBase == $(basename $ARG) ]]; then
				#~ list="${itemDir}/$(selected "${itemBase%.*}")${itemExt}"
			#~ else
				#~ list="${itemDir}/$(bold ${itemBase%.*})${itemExt}"
			#~ fi
		else
			list="${list}, $(formArg "$ARG" "deselected")"
		fi
	done
	
	if [[ ${#remFiles[@]} == 1 ]]; then
		echo -e "\n$(bold "${#remFiles[@]} File Left to Process:") ${list}\n"
	else
		echo -e "\n$(bold "${#remFiles[@]} Files Left to Process:") ${list}\n"
	fi

#PREPARATION

#Establish Basic Directory Structure.
	OUTDIR=$(readlinkF "$OUTDIR")
	
	if [ $OUTDIR != $PWD ]; then
		mkdir -p $OUTDIR
		#NO RISKS. WE REMEMBER THE LUT.py. RIP ad-hoc HALD LUT implementation :'( .
	fi
	
	local FILE="${OUTDIR}/${TRUNC_ARG}"
	local TMP="${FILE}/tmp_${TRUNC_ARG}"
	
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
			return 1
		fi
		
		DNG_LOC=${OUTDIR}/tmp_reused
		mkdir -p ${OUTDIR}/tmp_reused
		
		find $ARG -iname "*.dng" | xargs -I {} mv {} $DNG_LOC #Moving DNGs to temporary location.
		
		reuseSet "$ARG"
		#~ dngSet "$DNG_LOC"
		#~ FPS=`cat ${ARG}/../settings.txt | grep "FPS" | cut -d $" " -f2` #Grab FPS from previous run.
		#~ FRAMES=`cat ${ARG}/../settings.txt | grep "Frames" | cut -d $" " -f2` #Grab FRAMES from previous run.
		#~ KELVIN=`cat ${ARG}/../settings.txt | grep "WBKelvin" | cut -d $" " -f2`
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
		
		mkdirS $FILE dngLocClean; if [ $? -eq 1 ]; then return 1; fi
		mkdirS $TMP; if [ $? -eq 1 ]; then return 1; fi #Make the folders.
		
		find $DNG_LOC -iname "*.dng" | xargs -I {} mv {} $TMP #Moving files to where they need to go.
		cp "${DNG_LOC}/settings.txt" $FILE
				
		setBL=false
		DEVELOP=false
		rm -r $DNG_LOC
	elif [ -d $ARG ]; then #If it's a DNG sequence, but not a reused one.
		mkdirS $FILE; if [ $? -eq 1 ]; then return 1; fi
		mkdirS $TMP; if [ $? -eq 1 ]; then return 1; fi
		
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
		mkdirS $FILE; if [ $? -eq 1 ]; then return 1; fi
		mkdirS $TMP; if [ $? -eq 1 ]; then return 1; fi
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
			
			for range in "${fileRanges[@]}"; do echo $range; done | #For each frame range, assign a thread.
				xargs -I {} -P $THREADS -n 1 \
					bash -c "dng_par '{}' '$MLV_DUMP' '$REAL_MLV' '$DARK_PROC' 'no_data' '$smooth' '$TMP' '$FRAME_END' '$TRUNC_ARG' '$FRAME_START'"
			
			#Since dng_par must run in a subshell, globals don't follow. Must pass *everything* in.
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
		mkdirS $oldFiles; if [ $? -eq 1 ]; then return 1; fi
		
		if [[ $(${CR_HDR} "${TMP}/${TRUNC_ARG}_$(printf "%06d" $FRAME_START).dng") == *"ISO blending didn't work"* ]]; then
			invOption "The input wasn't shot Dual ISO!"
		fi
		
		find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
			bash -c "iso_par '{}' '$CR_HDR' '$TMP' '$FRAME_END' '$oldFiles' '$CHROMA_SMOOTH'"
				
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng) #Use the first DNG to get the new correct black level.

		echo -e "\n"
	fi
	
	if [ $setBL == true ]; then
		echo -e "BlackLevel: ${BLACK_LEVEL}" >> $FILE/settings.txt #Black level must now be set.
	fi
	
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
		mkdirS $toBal; if [ $? -eq 1 ]; then return 1; fi
		
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

#PROCESSING

#IMAGE PROCESSING
	if [ $IMAGES == true ] ; then
		echo -e "$(bold ${TRUNC_ARG}:) Processing Image Sequence from Frame ${FRAME_START} to ${FRAME_END}...\n"
		
#Define Image Directories, Create SEQ directory
		local SEQ="${FILE}/${IMG_FMT}_${TRUNC_ARG}"
		local PROXY="${FILE}/proxy_${TRUNC_ARG}"
		
		mkdirS $SEQ; if [ $? -eq 1 ]; then return 1; fi
		
		if [ $isJPG == true ]; then
			mkdirS $PROXY; if [ $? -eq 1 ]; then return 1; fi
		fi
		
#Run the parallel image processing
		iProc 
		
#FFMPEG Filter Application: Temporal Denoising, 3D LUTs, Deshake, hqdn Denoising, removegrain denoising, unsharp so far.
#See construction of $V_FILTERS in PREPARATION.
		if [[ $FFMPEG_FILTERS == true ]]; then
			tmpFiltered="${TMP}/filtered"
			tmpUnfiltered="${TMP}/unfiltered"
			mkdir $tmpFiltered
			mkdir $tmpUnfiltered
			
			#Give correct output.
			echo -e "\033[1mApplying Filters:\033[0m $(joinArgs ", " "${FILTER_ARR[@]}")...\n"
			
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
		mkdirS $DNG; if [ $? -eq 1 ]; then return 1; fi
		
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
}
