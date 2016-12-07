#!/bin/bash

#desc: The bulk image processing operations; from dcraw, to ffmpeg, to parallel functions.

dcrawOpt() {
	#usage: dcrawOpt | >>ppm data
	#desc: Find, develop, and splay raw DNG data as ppm, ready to be processed.
	
	find "${TMP}" -maxdepth 1 -iname "*.dng" -print0 | sort -z | tr -d "\n" | xargs -0 \
		$DCRAW -c -q $DEMO_MODE $FOUR_COLOR -k $BLACK_LEVEL $SATPOINT $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $WAVE_NOISE -o $SPACE $DEPTH
} #Is prepared to pipe all the files in TMP outwards.

dcrawImg() { #
	#usage: dcrawImg | >>ppm data
	#desc: Find and splay image sequence data as ppm, ready to be processed by ffmpeg.
	#note: Not working well. IM has trouble keeping itself linear. Kinda slow b/c ppm conversion, even if it worked...
	
	find "${SEQ}" -maxdepth 1 -iname "*.${IMG_FMT}" -print0 | sort -z | xargs -0 -I {} convert '{}' -set colorspace sRGB -colorspace RGB ppm:-
} #Finds all images, prints to stdout, without any operations, using convert. ppm conversion is inevitably slow, however...

mov_main() {
	#usage: >>ppm data | mov_main
	#desc: Creates the primary, high quality movie MOV file from input ppm data.
	
	ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
		-loglevel panic -stats $SOUND -vcodec prores_ks -pix_fmt rgb48be -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $V_FILTERS $SOUND_ACTION "${VID}_hq.mov"
} #-loglevel panic -stats

mov_prox() {
	#usage: >>ppm data | mov_prox
	#desc: Creates the lower quality movie MP4 file from input ppm data.
	
	ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
		-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast $V_FILTERS_PROX -crf 23 -c:a mp3 "${VID}_lq.mp4"
} #The option -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.

mov_main_img() {
	#usage: mov_main_img
	#desc: Creates the primary, high quality movie MOV file from the image sequence.
	
	ffmpeg -start_number $FRAME_START -loglevel panic -stats -f image2 -i ${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT} $SOUND -vcodec prores_ks \
		-pix_fmt rgb48le -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $V_FILTERS $SOUND_ACTION "${VID}_hq.mov"
}

mov_prox_img() {
	#usage: mov_prox_img
	#desc: Creates the lower quality movie MP4 file from the image sequence.
	
	ffmpeg -start_number $FRAME_START -loglevel panic -stats -f image2 -i ${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT} $V_FILTERS_PROX $SOUND -c:v libx264 \
		-n -r $FPS -preset veryfast -crf 21 -c:a mp3 -b:a 320k "${VID}_lq.mp4"
}

#PARALLEL FUNCTIONS

dng_par() {
	#usage: dng_par 1${} (frame range) 2$MLV_DUMP 3$REAL_MLV 4$DARK_PROC 5$no_data 6$smooth 7$TMP 8$FRAME_END 9$TRUNC_ARG 10$FRAME_START
	#arglength: Takes 10 args.
	#desc: Called by xargs; is capable of dumping DNGs with the mlv_dump backend in parallel by being run in a subshell.
	#note: Unfortunately, this means the entire relevant environment needs to be passed along too.
	
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

export -f dng_par #Export to run in subshell.

iso_par() {
	#usage: inc_iso 1${} 2$CR_HDR 3$TMP 4$FRAME_END 5$oldFiles 6$CHROMA_SMOOTH.
	#arglength: Takes 6 args.
	#desc: Called by xargs; is capable of processing Dual ISO DNGs in parallel by being run in a subshell.
	#note: Progress bar is thread safe. Experiment gone right :).
	#note: Unfortunately, this means the entire relevant environment needs to be passed along too.
	
	count=$(echo "$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) + 1" | bc) #Get count from filename.
	
	$2 $1 $6 >/dev/null 2>/dev/null #The LQ option, --mean23, is completely unusable in my opinion.
	
	name=$(basename "$1")
	mv "${3}/${name%.*}.dng" $5 #Move away original dngs.
	mv "${3}/${name%.*}.DNG" "${3}/${name%.*}.dng" #Rename *.DNG to *.dng.
	
	echo -e "\033[2K\rDual ISO Development: Frame ${count}/${4}\c"
}

export -f iso_par #Must expose function to subprocess.

img_par() { 
	#usage: img_par 1${} 2$DEMO_MODE 3$FOUR_COLOR 4$BADPIXELS 5$WHITE 6$HIGHLIGHT_MODE 7$GAMMA 8$WAVE_NOISE 9$DEPTH 10$SEQ 11$TRUNC_ARG 12$IMG_FMT 13$FRAME_END 14$DEPTH_OUT 15$COMPRESS 16$isJPG 17$PROXY_SCALE 18$PROXY 19$BLACK_LEVEL 20$SPACE 21$SATPOINT 22$DCRAW 23$FFMPEG_FILTERS
	#arglength: Takes 22 arguments.
	#desc: Called by xargs; is capable of developing images in parallel by being run in a subshell.
	#note: Unfortunately, this means the entire relevantenvironment needs to be passed along too.
	
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

export -f img_par #Need to export the function for it to be used in child functions.

#~ See http://www.imagemagick.org/discourse-server/viewtopic.php?t=21161


conv_par() {
	#usage: conv_par 1${} 2$TRUNC_ARG 3$outFolder 4$fromFMT 5$iccProf 6$toFMT 7$DEPTH_OUT 8$compress 9$FRAME_END 10$IMG_FMT
	#arglength: Takes 10 arguments.
	#desc: Called by xargs; is capable of converting images in parallel by being run in a subshell. Automatically applies the DPX hack.
	#note: Unfortunately, this means the entire relevant environment needs to be passed along too.
	
	count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Get count from filename.
	
	echo -e "\033[2K\rMiddle-step: ${4^^} to ${6^^}, Frame ${count^^}/${9}\c"
	
	DPXHACK=""
	if [[ ${6^^} == "DPX" && ${10^^} == ${6^^} ]]; then DPXHACK="-colorspace sRGB"; else DPXHACK=""; fi
	#Trust me, I've tried everything else; but this sRGB transform works. Must be an IM bug. Keep an eye on it!
	#The sRGB curve is only applied if going to DPX while DPX is the target image format. Aka. At the end; not in the middle.
	
	convert ${7} ${1} ${5} $8 -set colorspace RGB ${DPXHACK} "${3}/$(printf "${2}_%06d" ${count}).${6}"
}

export -f conv_par


#PRACTICAL PARALLEL FUNCTIONS

iProc() {
	#usage: iProc
	#desc: Develop the sequence from the current global settings.
	
#Define hardcoded compression based on IMG_FMT
	local COMPRESS=""
	if [ $isCOMPRESS == true ]; then
		case ${IMG_FMT} in
			exr)
				COMPRESS="-compress piz"
				;;
			tiff)
				COMPRESS="-compress zip"
				;;
			png)
				COMPRESS="-quality 0"
				;;
			dpx)
				COMPRESS="-compress rle"
				;;
		esac
	fi

#Convert all the actual DNGs to IMG_FMT, in parallel.
	find "${TMP}" -maxdepth 1 -name '*.dng' -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
		bash -c "img_par '{}' '$DEMO_MODE' '$FOUR_COLOR' '$BADPIXELS' '$WHITE' '$HIGHLIGHT_MODE' '$GAMMA' '$WAVE_NOISE' '$DEPTH' \
		'$SEQ' '$TRUNC_ARG' '$IMG_FMT' '$FRAME_END' '$DEPTH_OUT' '$COMPRESS' '$isJPG' '$PROXY_SCALE' '$PROXY' '$BLACK_LEVEL' '$SPACE' '$SATPOINT' '$DCRAW' '$FFMPEG_FILTERS'"
	
	# Removed  | cut -d '' -f $FRAME_RANGE , as this happens when creating the DNGs in the first place.

	if [ $isJPG == true ]; then #Make it print "Frame $FRAMES / $FRAMES" as the last output.
		echo -e "\033[2K\rDNG to ${IMG_FMT^^}/JPG: Frame ${FRAME_END}/${FRAME_END}\c"
	else
		echo -e "\033[2K\rDNG to ${IMG_FMT^^}: Frame ${FRAME_END}/${FRAME_END}\c"
	fi
	
	echo -e "\n"
}

tConvert() {
	#usage: tConvert 1$inFolder 2$outFolder 3$fromFMT 4$toFMT
	#desc: Convert an image sequence from fromFMT to toFMT, with i/o inFolder and outFolder.
	#note: optional icc profile. Wouldn't suggest using it right now...

	inFolder=$1
	outFolder=$2
	fromFMT=$3
	toFMT=$4
	iccProf=$5
	
	if [[ ! -z $iccProf ]]; then iccProf="+profile icm -profile $iccProf"; fi
	
	compress=""
	if [[ ${IMG_FMT^^} == ${toFMT^^} ]]; then compress=${COMPRESS}; fi
	
	find $inFolder -iname "*.${fromFMT}" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
		bash -c "conv_par '{}' '$TRUNC_ARG' '$outFolder' '$fromFMT' '$iccProf' '$toFMT' '$DEPTH_OUT' '$compress' '$FRAME_END' '$IMG_FMT'"
	
	echo ""
}

applyFilters() {
	#usage: applyFilters IO <FMT>
	#desc: Applies all ffmpeg filters to the given IO sequence of FMT format.
	#note: If FMT isn't defined, IMG_FMT is automatically used.
	#note: Ideally, this would be all we need. But alas, ffmpeg + exr is broken. So there's a custom middle step for that scenario.
	
	IO=$1
	FMT=$2
	
	if [[ -z $FMT ]]; then FMT="${IMG_FMT}"; fi
	
	ffmpeg -start_number $FRAME_START -f image2 -i "${IO}/${TRUNC_ARG}_%06d.${FMT}" -loglevel panic -stats $V_FILTERS \
		-pix_fmt rgb48be -start_number $FRAME_START "${tmpFiltered}/${TRUNC_ARG}_%06d.${FMT}"
	
	tConvert "$tmpFiltered" "$IO" "$FMT" "$FMT" # "/home/sofus/subhome/src/convmlv/color/lin_xyz--srgb_srgb.icc" - profile application didn't work...
}
