#!/bin/bash

#BASIC CONSTANTS
DEPS="imagemagick dcraw ffmpeg python3 pip3 exiftool xxd" #Dependency package names (Debian). List with -K option.
PIP_DEPS="numpy Pillow tifffile" #Technically, you don't need Pillow. I'm not really sure :).
VERSION="1.5.2" #Version string.
PYTHON="python3"

#NON-STANDARD FILE LOCATIONS
MLV_DUMP="./mlv_dump" #Path to mlv_dump location.
RAW_DUMP="./raw2dng" #Path to raw2dng location.
MLV_BP="./mlv2badpixels.sh"
PYTHON_BAL="./balance.py"

BAL="${PYTHON} ${PYTHON_BAL}"

#MODDABLE CONSTANTS
OUTDIR="$(pwd)/raw_conv"
isOutGen=false
MOVIE=false
FPS=24 #Will be read from .MLV.
IMAGES=false
COMPRESS=""
isJPG=false
isH264=false
KEEP_DNGS=false
FOUR_COLOR=""

#DCraw
HIGHLIGHT_MODE="0"
PROXY_SCALE="75%"
DEMO_MODE="1"
GAMMA="1 1"
DEPTH="-4"
DEPTH_OUT="-depth 16"
NOISE_REDUC=""
BADPIXELS=""
BADPIXEL_PATH=""
isBP=false

#White Balance
WHITE=""
GEN_WHITE=true
CAMERA_WB=false
WHITE_SPD=15

#LUT
LUT=""
isLUT=false


help () { #This is a little too much @ this point...
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
	echo -e "	-Python 3 + libs: Used for auto white balance."
	echo -e "	-exiftool + xxd: Used in mlv2badpixels.sh.\n"
	
	echo -e "VERSION: ${VERSION}\n"


	echo -e "OPTIONS, BASIC:"
	echo -e "	-v   version - Print out version string."
	echo -e "	-o<path>   OUTDIR - The path in which files will be placed (no space btwn -o and path)."
	echo -e "	-M<path>   MLV_DUMP - The path to mlv_dump (no space btwn -M and path). Default is './mlv_dump'."
	echo -e "	-R<path>   RAW_DUMP - The path to raw2dng (no space btwn -M and path). Default is './raw2dng'."
	echo -e "	-y<path>   PYTHON - The path or command used to invoke Python. Defaults to python3."
	echo -e "	-B<path>   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'.\n\n"
	
	echo -e "OPTIONS, OUTPUT:"
	echo -e "	-i   IMAGE - Specify to create a TIFF sequence.\n" 
	
	echo -e "	-c   COMPRESS - Specify to compress the TIFF sequence."
	echo -e "	  --> Uses ZIP compression for best 16-bit compression."
	
	echo -e "	-m   MOVIE - Specify to create a Prores4444 video.\n" 
		
	echo -e "	-p[0:3]   PROXY - Specifies the proxy mode." 
	echo -e "	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.\n"
	
	echo -e "	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output."
	echo -e "	  --> Use -s<percentage>% (no space). 50% is default.\n"
	
	echo -e "	-k   KEEP_DNGS - Specify if you want to keep the DNG files."
	echo -e "	  --> Besides testing, this makes the script a glorified mlv_dump...\n\n"
	
	echo -e "OPTIONS, RAW DEVELOPMENT:"
	echo -e "	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default."
	echo -e "	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.\n"
	
	echo -e "	-f   FOUR_COLOR - Interpolate RGB as four colors. Can often fix weirdness with demosaicing.\n"
	
	echo -e "	-H[0:9]   HIGHLIGHT_MODE - 2 looks the best, without major modifications. 0 is also a safe bet."
	echo -e "	  --> Use -H<number> (no space). 0 clips. 1 allows colored highlights. 2 adjusts highlights to grey."
	echo -e "	  --> 3 through 9 do highlight reconstruction with a certain tone. See dcraw documentation.\n"
	
	echo -e "	-b   BADPIXELS - Fix focus pixels issue using dfort's script."
	echo -e "	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src.\n"
	
	echo -e "	-a<path>   BADPIXEL_PATH - Use, appending to the generated one, your own .badpixels file. REQUIRES -b."
	echo -e "	  --> Use -a<path> (no space). How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686\n"
	
	echo -e "	-n[int]   NOISE_REDUC - This is the threshold of wavelet denoising - specify to use."
	echo -e "	  --> Use -n<number>. Defaults to no denoising. 150 tends to be a good setting; 350 starts to look strange.\n"
	
	echo -e "	-g[0:4]   GAMMA - This is a modal gamma curve that is applied to the image. 0 is default."
	echo -e "	  --> Use -g<mode> (no space). 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.\n"
	
	echo -e "	-S   SHALLOW - Specifying this option will create an 8-bit output instead of a 16-bit output."
	echo -e "	  --> It'll kind of ruin the point of RAW, though....\n\n"
	
	echo -e "OPTIONS, COLOR:"
	echo -e "	-w[0:3]   WHITE - This is a modal white balance setting. Defaults to 0. 1 doesn't always work very well."
	echo -e "	  --> Use -w<mode> (no space)."
	echo -e "	  --> 0: Auto WB (Requires Python Deps). 1: Camera WB. 2: No Change.\n"
	
	echo -e "	-A[int]   WHITE_SPD - This is the speed of the auto white balance, causing quality loss. Defaults to 15."
	echo -e "	  --> For AWB, the script averages the entire sequence, skipping n frames each time. This value is n.\n"
	
	echo -e "	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it."
	echo -e "	  --> Compatibility determined by ffmpeg (.cube is supported)."
	echo -e "	  --> Path to LUT (no space between -l and path). Without specifying -l, no LUT will be applied.\n\n"
	
	echo -e "OPTIONS, DEPENDENCIES:"
	echo -e "	-K   Debian Package Deps - Lists dependecies. Works with apt-get on Debian; should be similar elsewhere."
	echo -e "	  --> No operations will be done."
	echo -e "	  --> Example: sudo apt-get install $ (./convmlv -K)\n"
	
	echo -e "	-Y   Python Deps - Lists Python dependencies. Works with pip."
	echo -e "	  --> No operations will be done. "
	echo -e "	  --> Example: sudo pip3 install $ (./convmlv -Y)\n"
}

mkdirS() {
	path=$1
		
	if [ -d $path ]; then
		while true; do
			read -p "Overwrite ${path}? [y/n] " yn
			case $yn in
				[Yy]* ) rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
				;;
				[Nn]* ) echo -e "\n\e[0;31m\e[1mDirectory ${path} won't be created.\e[0m\n"; exit 0
				;;
				* ) echo -e "\e[0;31m\e[1mPlease answer yes or no.\e[0m\n"
				;;
			esac
		done
	else
		mkdir -p $path >/dev/null 2>/dev/null
	fi
	
}

parseArgs() { #Holy garbage
	if [ `echo ${ARG} | cut -c1-1` = "-" ]; then
		if [ `echo ${ARG} | cut -c2-2` = "H" ]; then
			HIGHLIGHT_MODE=`echo ${ARG} | cut -c3-3`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "s" ]; then
			PROXY_SCALE=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "f" ]; then
			FOUR_COLOR="-f"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "y" ]; then
			PYTHON=`echo ${ARG} | cut -c3-${#ARG}`
			BAL="${PYTHON} balance.py"
			
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "v" ]; then
			echo -e "convmlv v${VERSION}"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "m" ]; then
			MOVIE=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "c" ]; then
			COMPRESS="-compress zip"
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
			PROXY=`echo ${ARG} | cut -c3-3`
			case ${PROXY} in
				"0") isJPG=false; isH264=false
				;;
				"1") isJPG=false; isH264=true
				;;
				"2") isJPG=true; isH264=false
				;;
				"3") isJPG=true; isH264=true
				;;
			esac
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "i" ]; then
			IMAGES=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "o" ]; then
			OUTDIR=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "a" ]; then
			BADPIXEL_PATH=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "n" ]; then
			setting=`echo ${ARG} | cut -c3-${#ARG}`
			NOISE_REDUC="-n ${setting}"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "h" ]; then
			help
			exit 0
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
		if [ `echo ${ARG} | cut -c2-2` = "S" ]; then
			DEPTH=""
			DEPTH_OUT=""
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "w" ]; then
			mode=`echo ${ARG} | cut -c3-3`
			case ${mode} in
				"0") CAMERA_WB=false; GEN_WHITE=true #Will generate white balance.
				;;
				"1") CAMERA_WB=true; GEN_WHITE=false;
				;;
				"2") WHITE="-r 1 1 1 1"; CAMERA_WB=true; GEN_WHITE=false
				;;
			esac
		
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "K" ]; then
			echo $DEPS
			exit 0
		fi
		if [ `echo ${ARG} | cut -c2-2` = "l" ]; then
			LUT_PATH=`echo ${ARG} | cut -c3-${#ARG}`
			if [ ! -f $LUT_PATH ]; then
				echo "LUT not found!!!"
				echo $LUT_PATH
				exit 1
			fi
			LUT="lut3d=${LUT_PATH}"
			isLUT=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "b" ]; then
			isBP=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "k" ]; then
			KEEP_DNGS=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "B" ]; then
			MLV_BP=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "A" ]; then
			WHITE_SPD=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "Y" ]; then
			echo $PIP_DEPS
			exit 0
		fi
		continue
	fi
}

checkDeps() {
		if [ ! -f $ARG ]; then
			echo -e "\e[0;31m\e[1mFile ${ARG} not found!\e[0m\n"
			exit 1
		fi
		
		if [ ! -f $PYTHON_BAL ]; then
			echo -e "\e[0;31m\e[1mAWB ${PYTHON_BAL} not found! Execution will continue without AWB.\e[0m\n"
		fi
		
		if [ ! -f $MLV_DUMP ]; then
			echo -e "\e[0;31m\e[1m${MLV_DUMP} not found!\e[0m\n"
			exit 1
		fi
		if [ ! -f $RAW_DUMP ]; then
			echo -e "\e[0;31m\e[1m${RAW_DUMP} not found! Execution will continue without .RAW processing capability.\e[0m\n"
		fi
		
		if [ ! -f $MLV_BP ]; then
			echo -e "\e[0;31m\e[1m${RAW_DUMP} not found! Execution will continue without badpixel removal.\e[0m\n"
		fi
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
	
	PIPE="${TMP}/pipe_$(date +%s%N | cut -b1-13)"
	mkfifo $PIPE
	
	cat $PIPE | $cmd1 & $cmdOrig | tee $PIPE | $cmd2 #The magic of simultaneous execution ^_^
	#~ cat $PIPE | tr 'e' 'a' & echo 'hello' | tee $PIPE | tr 'e' 'o' #The magic of simultaneous execution ^_^
}


if [ $# == 0 ]; then
	help
	echo -e "\e[0;31m\e[1mNo arguments, no joy!!!\e[0m\n"
fi

ARGNUM=$#

for ARG in $*; do
#Evaluate command line arguments. ARGNUM decrements to keep track of how many files there are to process.
	parseArgs # <-- Has a continue statement inside of it.
	
#Check that main dependencies exist.
	checkDeps
	
#List remaining files to process.
	remFiles=${@:`echo "$# - ($ARGNUM - 1)" | bc`:$#}
	remArr=$(echo $remFiles)
	
	list=""
	for item in $remArr; do
		if [ -z "${list}" ]; then
			list="${item}"
		else
			list="${list}, ${item}"
		fi
	done
		
	echo -e "\n\e[1m${ARGNUM} Files Left to Process:\e[0m ${list}\n"

#PREPARATION

#Basic Directory Structure.
	if [ $OUTDIR != $PWD ] && [ isOutGen == false ]; then
		mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP OLD FRIEND.
		isOutGen=true
	fi
		
	BASE=$(basename "$ARG")
	EXT="${BASE##*.}"
	TRUNC_ARG="${BASE%.*}"
	
	FILE="${OUTDIR}/${TRUNC_ARG}"
	
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	
	mkdirS $FILE
	mkdirS $TMP
	
#Create badpixels file.
	if [ $isBP == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating badpixels file...\n"
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			$MLV_BP -o "${TMP}/${bad_name}" $ARG
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			$MLV_BP -o "${TMP}/${bad_name}" $ARG
		fi
		
		if [ ! -z $BADPIXEL_PATH ]; then
			if [ -f "${TMP}/${bad_name}" ]; then
				mv "${TMP}/${bad_name}" "${TMP}/bp_gen"
				cp $BADPIXEL_PATH "${TMP}/bp_imp"
				
				{ cat "${TMP}/bp_gen" && cat "${TMP}/bp_imp"; } > "${TMP}/${bad_name}" #Combine specified file with the generated file.
			else
				cp $BADPIXEL_PATH "${TMP}/${bad_name}"
			fi
		fi
		
		BADPIXELS="-P ${TMP}/${bad_name}"
	fi
	
#Dump to DNG sequence
	echo -e "\e[1m${TRUNC_ARG}:\e[0m Dumping to DNG Sequence...\n"
	
	if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
		FPS=`${MLV_DUMP} -v -m ${ARG} | grep FPS | awk 'FNR == 1 {print $3}'`
		$MLV_DUMP $ARG -o "${TMP}/${TRUNC_ARG}_" --dng --no-cs >/dev/null 2>/dev/null
	elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
		FPS=`$RAW_DUMP $ARG "${TMP}/${TRUNC_ARG}_" | awk '/FPS/ { print $3; }'` #Run the dump while awking for the FPS.
	fi
		
	FRAMES=`expr $(ls -1U ${TMP} | wc -l) - 1`
	
#Get White Balance correction factor (or ignore it all).
	echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating WB...\n"
	if [ $GEN_WHITE == true ]; then
		n=`echo "${WHITE_SPD} + 1" | bc`
		
		i=0
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do 
			if [ `echo "${i} % ${n}" | bc` -eq 0 ] || [ $i -eq 1 ]; then #Only develop every nth file - we're averaging, after all!
				dcraw -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -o 0 -T "${file}"
			fi
			echo -e "\e[2K\rWB Development: Frame ${i}/${FRAMES}.\c"
			let i++
		done
		
		toBal="${TMP}/toBal"
		mkdirS $toBal
		
		for tiff in $TMP/*.tiff; do
			mv $tiff $toBal #TIFF MOVEMENT
		done
		
		#Read result into a form dcraw likes.
		echo -e "Calculating Auto White Balance..."
		BALANCE=`$BAL $toBal`
		WHITE="-r ${BALANCE} 1.000000"
		echo -e "Correction Factor (RGB): ${BALANCE} 1.0\n"
		
	elif [ $CAMERA_WB == true ]; then
		echo -e "Retrieving Camera White Balance..."
		
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			BALANCE=`dcraw -T -w -v -c ${file} 2>&1 | awk '/multipliers/ { print $2, $3, $4 }'`
			break
		done
		WHITE="-r ${BALANCE} 1.0"
		echo -e "Correction Factor (RGB): ${BALANCE} 1.0\n"
	fi

	echo -e "\e[1m${TRUNC_ARG}:\e[0m Converting ${FRAMES} DNGs to TIFF...\n"

#Move .wav.
	SOUND_PATH="${TMP}/${TRUNC_ARG}_.wav"
	
	if [ ! -f $SOUND_PATH ]; then
		echo -e "*Not moving .wav, because it doesn't exist.\n"
	else
		echo -e "Moving .wav.\n"
		cp $SOUND_PATH $FILE
	fi
	
#New Fancy Stuff
	
	TIFF="${FILE}/tiff_${TRUNC_ARG}"
	PROXY="${FILE}/proxy_${TRUNC_ARG}"
	
	mkdirS $TIFF
	mkdirS $PROXY
	
	dcrawFile() {
		dcraw -c -q $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH $file
		#Requires some file outside the scope of the function.
	}
	
	dcrawOpt() {
		find "${TMP}" -maxdepth 1 -iname '*.dng' -print0 | sort -z | xargs -0 \
			dcraw -c -q $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH
	}
	
	img_main() {
		convert $DEPTH_OUT - $COMPRESS $(printf "${TIFF}/${TRUNC_ARG}_%06d.tiff" $i) #Make sure to do deep analysis later.
		#Requires some variable i outside the scope of the function.
	}
	
	img_prox() {
		convert - -quality 90 $(printf "${PROXY}/${TRUNC_ARG}_%06d.jpg" $i)
	}
	
	i=0
	trap "rm -rf ${FILE}; exit 1" INT
	for file in $TMP/*.dng; do
		if [ $isJPG == true ]; then
			runSim dcrawFile img_main img_prox
		else
			dcrawFile $file | img_main
		fi
		echo -e "\e[2K\rDNG Development (dcraw): Frame ${i}/${FRAMES}.\c"
		let i++
	done
	
	exit 1
	
	mov_main() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -vcodec prores_ks -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $LUT $SOUND_ACTION "${VID}_hq.mov"
	} #-loglevel panic -stats
	
	mov_prox() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast -vf "scale=trunc(iw/2)*${SCALE}:trunc(ih/2)*${SCALE}" -crf 23 $LUT -c:a mp3 "${VID}_lq.mp4"
	} #The option -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.
	
	#~ exit 0

#IMAGE PROCESSING
	if [ $IMAGES == true ] ; then
		echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Processing Image Sequence..."
		
#Define Image Directories, Create TIFF directory
		TIFF="${FILE}/tiff_${TRUNC_ARG}"
		PROXY="${FILE}/proxy_${TRUNC_ARG}"
		
		mkdirS $TIFF
		mkdirS $PROXY
		
#Convert all the actual DNGs to TIFFs.
		i=0
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			dcraw -q $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH -T "${file}"
			echo -e "\e[2K\rDNG Development (dcraw): Frame ${i}/${FRAMES}.\c"
			let i++
		done
		
#Potentially apply a LUT.
		if [ $isLUT == true ]; then
			echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Applying LUT to ${FRAMES} TIFFs...\n"
			
			ffmpeg -f image2 -i "${TMP}/${TRUNC_ARG}_%06d.tiff" -loglevel panic -stats -vf $LUT "${TIFF}/LUT_${TRUNC_ARG}_%06d.tiff"
			
			rm $TMP/*.tiff
		fi
		
		echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Processing ${FRAMES} TIFFs...\n"
		
		jpgProxy() {
			i=0
			trap "rm -rf ${FILE}; exit 1" INT
			for tiff in $TMP/*.tiff; do	
				output=$(printf "${PROXY}/${TRUNC_ARG}_%06d" ${i})
				convert -quiet $tiff -resize $PROXY_SCALE "${output}.jpg"  > /dev/null #PROXY GENERATION
				
				echo -e "\e[2K\rProxy Generation (IM): Frame ${i}/${FRAMES}.\c"
				let i++
			done
		}

#Image Proxy Generation
		if [ $isJPG == true ]; then
			mkdirS $PROXY #No need to create the proxy directory until we know that proxies are being made.
			jpgProxy
		fi
		
		#Move tiffs into place.
		trap "rm -rf ${FILE}; exit 1" INT
		for tiff in $TMP/*.tiff; do	
			mv $tiff $TIFF >/dev/null 2>/dev/null #Gets mad if a LUT was applied, as all the tiffs are then deleted. Suppress and noone will know :).
		done
fi
	
	
#MOVIE PROCESSING
	if [ $MOVIE = true ]; then
		VID="${FILE}/${TRUNC_ARG}"
		SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor, *2 for 50%
		
		SOUND="-i ${TMP}/${TRUNC_ARG}_.wav"
		SOUND_ACTION="-c:a mp3"
		if [ ! -f $SOUND_PATH ]; then
			SOUND=""
			SOUND_ACTION=""
		fi
		
		#LUT is automatically applied if argument was passed.
		
		#Here we go!
		if [ $isH264 == true ]; then
			echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes and Proxy..."
			
			bench() {
				first=`echo "$(date +%s%N | cut -b1-13) / 1000" | bc -l`
				$1
				end=`echo "($(date +%s%N | cut -b1-13) / 1000 ) - ${first}" | bc -l`
				echo $end
			} #Just a test :).
			
			#~ cat $PIPE | vidLQ & echo "text" | tee $PIPE | vidHQ # Old method. Surprised it worked... Slightly faster.
			
			runSim dcrawOpt mov_main mov_prox
			
		else
			echo -e "\n\n\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			vidHQ
		fi
	fi
	
	echo -e "\n\e[1mCleaning Up.\e[0m\n"
	
#Potentially move DNGs.
	if [ $KEEP_DNGS == true ]; then
		DNG="${FILE}/dng_${TRUNC_ARG}"
		mkdirS $DNG
		
		trap "rm -rf ${DNG}; exit 1" INT
		for dng in $TMP/*.dng; do
			mv $dng $DNG
		done
	fi
	
#Delete tmp
	rm -rf $TMP
	
	let ARGNUM--
done

exit 0
