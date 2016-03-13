#!/bin/bash

#BASIC CONSTANTS
MLV_DUMP="./mlv_dump" #Path to mlv_dump location.
RAW_DUMP="./raw2dng" #Path to raw2dng location.
MLV_BP="./mlv2badpixels.sh"
PYTHON="python3"

BAL=""

DEPS="imagemagick dcraw ffmpeg python3 pip3" #Dependency package names (Debian). List with -K option.
PIP_DEPS="numpy Pillow tifffile" #Technically, you don't need Pillow. I'm not really sure :).
VERSION="1.4.0" #Version string.

#MODDABLE CONSTANTS
OUTDIR="$(pwd)"

HIGHLIGHT_MODE="0"
PROXY_SCALE="50%"
DEMO_MODE="1"
HQ_MOV=false
LQ_PROXY=false
DELETE_IMGS=false
GAMMA="1 1"
DEPTH="-4"
WHITE=""
LUT=""
isLUT=false
NOISE_REDUC=""
BADPIXELS=""
isBP=false
GEN_WHITE=false
isMLV=true


help () {
	echo -e "Usage:\n	\033[1m./convmlv.sh\033[0m [OPTIONS] \033[2mmlv_files\033[0m\n"
			
	echo -e "INFO:\n	A script allowing you to convert .MLV or .RAW files into TIFF + JPG (proxy) sequences and/or a Prores 4444 .mov,
	with an optional H.264 .mp4 preview. Many useful options are exposed.\n"

	echo -e "DEPENDENCIES: *If you don't use a feature, you don't need the dependency!"
	echo -e "	-mlv_dump: For DNG extraction from MLV. http://www.magiclantern.fm/forum/index.php?topic=7122.0"
	echo -e "	-raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0"
	echo -e "	-mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src"
	echo -e "	-dcraw: For RAW development."
	echo -e "	-ffmpeg: For video creation."
	echo -e "	-ImageMagick: Used for making proxy sequence."
	echo -e "	-Python 3 + libs: Used for auto white balance.\n"
	
	echo -e "VERSION: ${VERSION}\n"


	echo -e "OPTIONS:"
	echo -e "	-v   version - Print out version string."
	echo -e "	-o<path>   OUTDIR - The path in which files will be placed (no space btwn -o and path)."
	echo -e "	-M<path>   MLV_DUMP - The path to mlv_dump (no space btwn -M and path). Default is './mlv_dump'."
	echo -e "	-R<path>   RAW_DUMP - The path to raw2dng (no space btwn -M and path). Default is './raw2dng'."
	echo -e "	-y<path>   PYTHON - The path or command used to invoke Python. Defaults to python3."
	echo -e "	-B<path>   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'.\n"
		
	echo -e "	-H[0:9]   HIGHLIGHT_MODE - 3 to 9 does degrees of colored highlight reconstruction, 1 and 2 allow clipping. 0 is default."
	echo -e "	  --> Use -H<number> (no space).\n"
	
	echo -e "	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output."
	echo -e "	  --> Use -s<double-digit number>% (no space). 50% is default.\n"
	
	echo -e "	-m   HQ_MOV - Use to create a Prores 4444 file.\n"
	
	echo -e "	-p   LQ_MOV - Use to create a low quality H.264 mp4 from the proxies.\n"
	
	echo -e "	-D   DELETE_IMGS - Use to delete not only TMP, but also the TIF and proxy sequences."
	echo -e "	  --> Useful if all you want are video files.\n"
	
	echo -e "	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default."
	echo -e "	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.\n"
	
	echo -e "	-K   Debian Package Deps - Lists dependecies. Works with apt-get on Debian; should be similar elsewhere."
	echo -e "	  --> No operations will be done.\n"
	echo -e "	  --> Example: sudo apt-get install $ (./convmlv -K)\n"
	
	echo -e "	-Y   Python Deps - Lists Python dependencies. Works with pip."
	echo -e "	  --> No operations will be done. "
	echo -e "	  --> Example: sudo pip3 install $ (./convmlv -Y)\n"
	
	echo -e "	-g[0:4]   GAMMA - This is a modal gamma curve that is applied to the image. 0 is default."
	echo -e "	  --> Use -g<mode> (no space). 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.\n"
	
	echo -e "	-P   DEPTH - Specifying this option will create an 8-bit output instead of a 16-bit output."
	echo -e "	  --> It'll kind of ruin the point of RAW, though....\n"
	
	echo -e "	-W[0:3]   WHITE - This is a modal white balance setting. Defaults to 0. 1 doesn't always work very well."
	echo -e "	  --> Use -W<mode> (no space)."
	echo -e "	  --> 0: Auto WB (Requires Python Deps). 1: Camera WB (If retrievable). 2: No WB Change. 3: Custom WB (\n"
	
	echo -e "	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it."
	echo -e "	  --> Compatibility determined by ffmpeg (.cube is supported)."
	echo -e "	  --> Path to LUT (no space between -l and path). Without specifying -l, no LUT will be applied.\n"
	
	echo -e "	-n[int]   NOISE_REDUC - This is the threshold of wavelet denoising - specify to use."
	echo -e "	  --> Use -n<number>. Defaults to no denoising. 150 tends to be a good setting; 350 starts to look strange.\n"
	
	echo -e "	-b   BADPIXELS - Fix focus pixels issue using dfort's script."
	echo -e "	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src."
}

mkdirS() {
	path=$1
	
	mkdir -p $path >/dev/null 2>/dev/null
	OUT=$?
	
	if [[ $OUT != 0 ]]; then
		while true; do
			read -p "Overwrite ${path}? (y/n) " yn
			case $yn in
				[Yy]* ) rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null
				;;
				[Nn]* ) echo -e "\n\e[0;31m\e[1mDirectory ${path} cannot be created.\e[0m\n"; exit 0
				;;
				* ) echo -e "\e[0;31m\e[1mPlease answer yes or no.\e[0m\n"
				;;
			esac
		done
	fi
	
}

parseArgs() {
	if [ `echo ${ARG} | cut -c1-1` = "-" ]; then
		if [ `echo ${ARG} | cut -c2-2` = "H" ]; then
			HIGHLIGHT_MODE=`echo ${ARG} | cut -c3-3`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "s" ]; then
			if [ `echo ${ARG} | cut -c3-5` = "00" ]; then
				PROXY_SCALE="100%"
			else
				PROXY_SCALE=`echo ${ARG} | cut -c3-5`
			fi
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "y" ]; then
			PYTHON=`echo ${ARG} | cut -c3-${#ARG}`
			BAL="${PYTHON} balance.py"
			
			let ARGNUM--
		else
			BAL="${PYTHON} balance.py"
		fi
		if [ `echo ${ARG} | cut -c2-2` = "v" ]; then
			echo -e "convmlv: v${VERSION}"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "m" ]; then
			HQ_MOV=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "M" ]; then
			MLV_DUMP=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "R" ]; then
			RAW_DUMP=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "p" ]; then
			LQ_PROXY=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "D" ]; then
			DELETE_IMGS=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "o" ]; then
			OUTDIR=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "n" ]; then
			setting=`echo ${ARG} | cut -c3-${#ARG}`
			NOISE_REDUC="-n ${setting}"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "h" ]; then
			help
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "d" ]; then
			DEMO_MODE=`echo ${ARG} | cut -c3-3`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "g" ]; then
			mode=`echo ${ARG} | cut -c3-3`
			case ${mode} in
				"0") GAMMA="1 1"
				;;
				"1") GAMMA="2.2 0"
				;;
				"2") GAMMA="1.8 0"
				;;
				"3") GAMMA="2.4 12.9"
				;;
				"4") GAMMA="2.222 4.5"
				;;
			esac
		
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "P" ]; then
			DEPTH=""
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "W" ]; then
			mode=`echo ${ARG} | cut -c3-3`
			case ${mode} in
				"0") GEN_WHITE=true #Will generate white balance.
				;;
				"1") WHITE="-w"
				;;
				"2") WHITE="-r 1 1 1 1"
				;;
			esac
		
			let ARGNUM--
		else
			GEN_WHITE=true
		fi
		if [ `echo ${ARG} | cut -c2-2` = "K" ]; then
			echo $DEPS
			exit 0
		fi
		if [ `echo ${ARG} | cut -c2-2` = "l" ]; then
			LUT=`echo ${ARG} | cut -c3-${#ARG}`
			if [ ! -f $LUT ]; then
				echo "LUT not found!!!"
				echo $LUT
				exit 1
			fi
			isLUT=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "b" ]; then
			isBP=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "B" ]; then
			MLV_BP=`echo ${ARG} | cut -c3-${#ARG}`
			if [ ! -f $MLV_BP ]; then
				echo "mlv2badpixels.sh not found!!!"
				echo $MLV_BP
				exit 1
			fi
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "Y" ]; then
			echo $PIP_DEPS
			exit 0
		fi
		continue
	fi
	
	#Check that file exists.
	if [ ! -f $ARG ]; then
		echo -e "\e[0;31m\e[1mFile ${ARG} not found!\e[0m\n"
		exit 1
	fi
}

if [ $# == 0 ]; then
	echo -e "\e[0;31m\e[1mNo arguments, no joy!!!\e[0m\n"
	help
fi

ARGNUM=$#

trap "rm -rf ${TMP} ${NEW} ${PROXY}; exit 1" INT
for ARG in $*; do
	#Evaluate command line arguments. ARGNUM decrements to keep track of how many files there are to process.
	parseArgs
	
	#Check that file exists.
	if [ ! -f $ARG ]; then
		echo -e "\e[0;31m\e[1mFile ${ARG} not found!\e[0m\n"
		exit 1
	fi
	
	echo -e "\n\e[1mFiles Left to Process: \e[0m${ARGNUM}\n"
	
	#Create directory structure.
	mkdirS $OUTDIR
		
	BASE=$(basename "$ARG")
	EXT="${BASE##*.}"
	TRUNC_ARG="${BASE%.*}"
		
	FILE="${OUTDIR}/${TRUNC_ARG}"
	
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	TIFF="${FILE}/tiff_${TRUNC_ARG}"
	PROXY="${FILE}/proxy_${TRUNC_ARG}"
		
	mkdirS $TMP
	mkdirS $TIFF
	mkdirS $PROXY
	
	#Optionally create badpixels file.
	if [ $isBP == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating badpixels file..."
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		$MLV_BP -o "${TMP}/${bad_name}" $ARG
		
		BADPIXELS="-P ${TMP}/${bad_name}"
	fi
	
	#Dump to DNG sequence
	echo -e "\n\e[1m${TRUNC_ARG}:\e[0m Dumping to DNG Sequence..."
	
	if [ ! -f $MLV_DUMP ]; then
		echo -e "\e[0;31m\e[1mmlv_dump not found at path ${MLV_DUMP}!!!\e[0m\n"
		exit 1
	fi
	
	if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
		$MLV_DUMP $ARG -o "${TMP}/${TRUNC_ARG}_" --dng --no-cs >/dev/null 2>/dev/null
	elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
		$RAW_DUMP $ARG "${TMP}/${TRUNC_ARG}_"
	fi
	
	FRAMES=`expr $(ls -1U ${TMP} | wc -l) - 1`
	
	#Do fastest possible dcraw conversion to get auto white balance (Ideally, read directly from MLV)
	echo -e "\n\e[1m${TRUNC_ARG}:\e[0m Generating Auto WB...\n"
	if [ $GEN_WHITE == true ]; then
		i=1
		for file in $TMP/*.dng; do #But why??? Only from a tiff sequence can we read white balance.
			dcraw -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -o 0 -T "${file}"
			echo -e "\e[2K\rWB Development: Frame ${i}/${FRAMES}.\c"
			let i++
		done
		
		toBal="${TMP}/toBal"
		mkdirS $toBal
		
		for tiff in $TMP/*.tiff; do
			mv $tiff $toBal #TIFF MOVEMENT
		done
		
		#Read result into a form dcraw likes.
		BALANCE=`$BAL $toBal`
		echo -e "\n\nCalculating White Balance..."
		WHITE="-r ${BALANCE} 1.000000"
		echo -e "Correction Factor (RGB): $BALANCE"
	fi

	echo -e "\n\e[1m${TRUNC_ARG}:\e[0m Converting ${FRAMES} DNGs to TIFF...\n"
	
	#Convert all the actual DNGs to TIFFs, in more correct ways.
	trap "rm -rf ${TMP} ${TIFF} ${PROXY}; exit 1" INT
	i=1
	for file in $TMP/*.dng; do
		dcraw -q $DEMO_MODE $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH -T "${file}"
		echo -e "\e[2K\rDNG Development (dcraw): Frame ${i}/${FRAMES}.\c"
		let i++
	done
	
	#Potentially apply a LUT.
	if [ $isLUT == true ]; then
		echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Applying LUT to ${FRAMES} TIFFs...\n"
		trap "rm -rf ${TMP} ${TIFF} ${PROXY}; exit 1" INT
		i=1
		for tiff in $TMP/*.tiff; do
			output=$(printf "${TMP}/LUT_${TRUNC_ARG}_%06d" ${i})
			ffmpeg -i $tiff -loglevel panic -vf lut3d="${LUT}" "${output}.tiff"
			rm $tiff
			echo -e "\e[2K\rApplying LUT (ffmpeg): Frame ${i}/${FRAMES}.\c"
			let i++
		done
	fi
	
	echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Processing ${FRAMES} TIFFs & Generating Proxies...\n"
	
	#Move tiffs into place and generate proxies.
	trap "rm -rf ${TMP} ${TIFF} ${PROXY}; exit" INT
	i=1
	for tiff in $TMP/*.tiff; do
		output=$(printf "${PROXY}/${TRUNC_ARG}_%06d" ${i})
		convert -quiet $tiff -resize $PROXY_SCALE "${output}.jpg"  > /dev/null #PROXY GENERATION
		
		mv $tiff $TIFF #TIFF MOVEMENT
		
		echo -e "\e[2K\rProxy Generation (IM): Frame ${i}/${FRAMES}.\c"
				
		let i++
	done
	
	#Move .wav.
	if [ ! -f "${TMP}/${TRUNC_ARG}_.wav" ]; then
		echo -e "\n*Not moving .wav, because it doesn't exist."
	else
		mv "${TMP}/${TRUNC_ARG}_.wav" $OUTDIR
	fi

	#Movie creation, for editing:

	echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Processing video options..."
	
	VID="${FILE}/${TRUNC_ARG}"
	
	# --> Potentially create High Quality Prores 4444: 
	if [ $HQ_MOV == true ]; then
		echo -e "\n\e[1mHigh Quality (Prores 4444) Video: \e[0m"
		if [ ! -f "${TMP}/${TRUNC_ARG}_.wav" ]; then
			ffmpeg -f image2 -i "${TIFF}/${TRUNC_ARG}_%06d.tiff" -loglevel panic -stats -vcodec prores_ks -profile:v 4444 -alpha_bits 0 -vendor ap4h "${VID}_hq.mov"
		else
			ffmpeg -f image2 -i "${TIFF}/${TRUNC_ARG}_%06d.tiff" -i "${OUTDIR}/${TRUNC_ARG}_.wav" -loglevel panic -stats -vcodec prores_ks -alpha_bits 0 -vendor ap4h -c:a copy "${VID}_hq.mov"
		fi
		
	fi
	
	# --> Potentially create proxy H.264: Highly unsuited for any color work; just a preview.
	if [ $LQ_PROXY == true ]; then
		echo -e "\n\e[1mLow Quality (H.264) Video: \e[0m"
		if [ ! -f "${TMP}/${TRUNC_ARG}_.wav" ]; then
			ffmpeg -f image2 -i "${PROXY}/${TRUNC_ARG}_%06d.jpg" -loglevel panic -stats -c:v libx264 -preset fast -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -crf 23 "${VID}_lq.mp4"
		else
			ffmpeg -f image2 -i "${PROXY}/${TRUNC_ARG}_%06d.jpg" -i "${OUTDIR}/${TRUNC_ARG}_.wav" -loglevel panic -stats -c:v libx264 -preset fast -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -crf 23 -c:a mp3 "${VID}_lq.mp4"
		fi
	fi
	#-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.
	
	echo -e "\n\e[1mDeleting files.\e[0m\n"

	#Potentially delete TIFFs and JPGs.
	if [ $DELETE_IMGS = true ]; then
		rm -rf $TIFF
		rm -rf $PROXY
	fi
	
	#Delete tmp
	rm -rf $TMP
	
	let ARGNUM--
done

exit 0
