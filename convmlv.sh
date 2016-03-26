#!/bin/bash

#~ The MIT License (MIT)

#~ Copyright (c) [year] [fullname]

#~ Permission is hereby granted, free of charge, to any person obtaining a copy
#~ of this software and associated documentation files (the "Software"), to deal
#~ in the Software without restriction, including without limitation the rights
#~ to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#~ copies of the Software, and to permit persons to whom the Software is
#~ furnished to do so, subject to the following conditions:

#~ The above copyright notice and this permission notice shall be included in all
#~ copies or substantial portions of the Software.

#~ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#~ IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#~ FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#~ AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#~ LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#~ OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#~ SOFTWARE.


#BASIC CONSTANTS
DEPS="imagemagick dcraw ffmpeg python3 pip3 exiftool xxd" #Dependency package names (Debian). List with -K option.
PIP_DEPS="numpy Pillow tifffile" #Technically, you don't need Pillow. I'm not really sure :).
VERSION="1.7.0" #Version string.
PYTHON="python3"
THREADS=8

#NON-STANDARD FILE LOCATIONS
MLV_DUMP="./mlv_dump" #Path to mlv_dump location.
RAW_DUMP="./raw2dng" #Path to raw2dng location.
CR_HDR="./cr2hdr" #Path to cr2hdr location.
MLV_BP="./mlv2badpixels.sh"
PYTHON_BAL="./balance.py"
DARKFRAME=""

BAL="${PYTHON} ${PYTHON_BAL}"

#MODDABLE CONSTANTS
OUTDIR="$(pwd)/raw_conv"
isOutGen=false
MOVIE=false
FPS=24 #Will be read from .MLV.
IMAGES=false
IMG_FMT="exr"
COMPRESS=""
isCOMPRESS=false
isJPG=false
isH264=false
KEEP_DNGS=false

#ISO
DUAL_ISO=false

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
FOUR_COLOR=""

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
			
	echo -e "INFO:\n	A script allowing you to convert .MLV, .RAW, or a folder with a DNG sequence into a sequence/movie
	with optional proxies. Many useful options are exposed, including formats (EXR by default).\n"

	echo -e "DEPENDENCIES: *If you don't use a feature, you don't need the dependency. Don't use a feature without the dependency."
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
	echo -e "	-B<path>   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'."
	echo -e "	-T[int]    Max process threads, for multithreaded parts of the program. Defaults to 8.\n\n"
	
	echo -e "OPTIONS, OUTPUT:"
	echo -e "	-i   IMAGE - Specify to create an image sequence (EXR by default).\n" 
	
	echo -e "	-f[0:3]   IMG_FMT - Create a sequence of <format> format, instead of a TIFF sequence."
	echo -e "	  --> 0: EXR (default), 1: TIFF, 2: PNG, 3: Cineon (DPX).\n" #Future: More formats?
	
	echo -e "	-c   COMPRESS - Specify to automatically compress the image sequence."
	echo -e "	  --> TIFF: ZIP (best for 16-bit), PIZ for EXR (best for grainy images), PNG: lvl 9 (zlib deflate), DPX: RLE."
	echo -e "	  --> EXR's piz compression tends to be fastest + best.\n"
	
	echo -e "	-m   MOVIE - Specify to create a Prores4444 video.\n"
		
	echo -e "	-p[0:3]   PROXY - Specifies the proxy mode. 0 is default." 
	echo -e "	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both."
	echo -e "	  --> Proxies won't be developed without the main output - ex. JPG proxies require -i.\n"
	
	echo -e "	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output."
	echo -e "	  --> Use -s<percentage>% (no space). 50% is default.\n"
	
	echo -e "	-k   KEEP_DNGS - Specify if you want to keep the DNG files."
	echo -e "	  --> Besides testing, this makes the script a glorified mlv_dump...\n\n"
	
	echo -e "OPTIONS, RAW DEVELOPMENT:"
	echo -e "	-u    DUAL_ISO - Process file as dual ISO.\n"
	
	echo -e "	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default."
	echo -e "	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.\n"
	
	echo -e "	-r   FOUR_COLOR - Interpolate as four colors. Can often fix weirdness with VNG/AHD.\n"
	
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
	
	echo -e "	-F<path>   DARKFRAME - This is the path to the dark frame MLV."
	echo -e "	  --> This is a noise reduction technique: Record 5 sec w/lens cap on & same settings as footage."
	echo -e "	  --> Pass in that MLV file (must be MLV) as <path> to get noise reduction on all passed MLV files.\n"
	
	echo -e "	-A[int]   WHITE_SPD - This is the amount of samples from which AWB will be calculated."
	echo -e "	  -->About this many frames, averaged over the course of the sequence, will be used to do AWB.\n"
	
	echo -e "	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it."
	echo -e "	  --> Compatibility determined by ffmpeg (.cube is supported)."
	echo -e "	  --> LUT cannot be applied to EXR sequences."
	echo -e "	  --> Path to LUT (no space between -l and path).\n\n"
	
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
				[Yy]* ) echo -e ""; rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
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
		if [ `echo ${ARG} | cut -c2-2` = "u" ]; then
			DUAL_ISO=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "F" ]; then
			DARKFRAME=`echo ${ARG} | cut -c3-${#ARG}`
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "r" ]; then
			FOUR_COLOR="-f"
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "f" ]; then
			mode=`echo ${ARG} | cut -c3-3`
			case ${mode} in
				"0") IMG_FMT="exr"
				;;
				"1") IMG_FMT="tiff"
				;;
				"2") IMG_FMT="png"
				;;
				"3") IMG_FMT="dpx"
				;;
			esac
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
			isCOMPRESS=true
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
		if [ `echo ${ARG} | cut -c2-2` = "T" ]; then
			setting=`echo ${ARG} | cut -c3-${#ARG}`
			THREADS=$setting
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
		if [ ! -f $ARG ] && [ ! -d $ARG ]; then
			echo -e "\e[0;31m\e[1mFile ${ARG} not found!\e[0m\n"
			exit 1
		fi
		
		if [ ! -f $DARKFRAME ] && [ $DARKFRAME != "" ]; then
			echo -e "\e[0;31m\e[1mDarkframe MLV ${DARKFRAME} not found!\e[0m\n"
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
			echo -e "\e[0;31m\e[1m${MLV_BP} not found! Execution will continue without badpixel removal.\e[0m\n"
		fi
		if [ ! -f $CR_HDR ]; then
			echo -e "\e[0;31m\e[1m${CR_HDR} not found! Execution will continue without Dual ISO processing capability.\e[0m\n"
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
	
	PIPE="${TMP}/pipe_vid" # $(date +%s%N | cut -b1-13)"
	mkfifo $PIPE 2>/dev/null
	
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
	
	if [ $ARGNUM == 1 ]; then
		echo -e "\n\e[1m${ARGNUM} File Left to Process:\e[0m ${list}\n"
	else
		echo -e "\n\e[1m${ARGNUM} Files Left to Process:\e[0m ${list}\n"
	fi

#PREPARATION

#Basic Directory Structure.
	if [ $OUTDIR != $PWD ] && [ isOutGen == false ]; then
		mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP OLD FRIEND.
		isOutGen=true
	fi
		
	BASE="$(basename "$ARG")"
	EXT="${BASE##*.}"
	TRUNC_ARG="${BASE%.*}"
	
	FILE="${OUTDIR}/${TRUNC_ARG}"
	
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	
	mkdirS $FILE
	mkdirS $TMP
	
#Create badpixels file, IF dual_iso isn't active.
	if [ $isBP == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating badpixels file...\n"
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		gen_bad="${TMP}/${bad_name}"
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			$MLV_BP -o $gen_bad $ARG
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			$MLV_BP -o $gen_bad $ARG
		fi
		
		#~ if [ $DUAL_ISO == true ]; then #Brute force grid in everything. Experiment.
			#~ echo "" > $gen_bad
			#~ echo $gen_bad
			#~ mapfile < $gen_bad
			#~ mFile=$(echo "${MAPFILE[@]}")
			#~ echo $file
			#~ exit
			#~ for line in $mFile; do
				#~ if ($(echo "${line}" | cut -c1-1) == "#"); then
					#~ continue
				#~ fi
				#~ xyd=(`echo ${line}`);
				#~ echo $line
				#~ echo hi
				#~ exit
				#~ 
				#~ #3x3 badpixel fill in.
				#~ for x in {-1..1}; do
					#~ for y in {-2..2}; do
						#~ if [ x == 0 ] || [ y == 0 ]; then
							#~ continue
						#~ fi
						#~ echo "$(echo "${xyd[0]} + $x" | bc) $(echo "${xyd[1]} + $y" | bc) 0" > $gen_bad
					#~ done
				#~ done
			#~ done
		#~ fi
		
		if [ ! -z $BADPIXEL_PATH ]; then
			if [ -f "${TMP}/${bad_name}" ]; then
				mv "${TMP}/${bad_name}" "${TMP}/bp_gen"
				cp $BADPIXEL_PATH "${TMP}/bp_imp"
				
				{ cat "${TMP}/bp_gen" && cat "${TMP}/bp_imp"; } > "${TMP}/${bad_name}" #Combine specified file with the generated file.
			else
				cp $BADPIXEL_PATH "${TMP}/${bad_name}"
			fi
		fi
		
		BADPIXELS="-P ${gen_bad}"
	fi
	
#Darkframe Averaging
	if [ $DARKFRAME != "" ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Creating darkframe for subtraction...\n"
		
		avgFrame="${TMP}/darkframe.MLV"
		newArg="${TMP}/subtracted.MLV"
		
		$MLV_DUMP -o "${avgFrame}" -a $DARKFRAME >/dev/null 2>/dev/null
		$MLV_DUMP -o $newArg -s $avgFrame $ARG >/dev/null 2>/dev/null
	fi
	
#Dump to DNG sequence, perhaps subtracting darkframe.
	if [ -d $ARG ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Using specified folder of RAW sequences...\n" #Use prespecified DNG sequence.
		find $ARG -iname "*.dng" | xargs -I {} cp {} $TMP #Copying DNGs to TMP.
		FPS=24 #Set FPS just in case.
		FRAMES=$(find ${TMP} -name "*.dng" | wc -l)
	else
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Dumping to DNG Sequence...\n"
				
		if [ $DARKFRAME != "" ]; then #Whether or not to use the newArg subtracted MLV.
			inputFile=$newArg
			rawStat="*Skipping Darkframe subtraction for RAW file ${TRUNC_ARG}."
		else
			inputFile=$ARG
			rawStat="\c"
		fi
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			FPS=`${MLV_DUMP} -v -m ${inputFile} | grep FPS | awk 'FNR == 1 {print $3}'`
			$MLV_DUMP $inputFile -o "${TMP}/${TRUNC_ARG}_" --dng --no-cs >/dev/null 2>/dev/null
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			echo -e $rawStat
			FPS=`$RAW_DUMP $inputFile "${TMP}/${TRUNC_ARG}_" | awk '/FPS/ { print $3; }'` #Run the dump while awking for the FPS.
		fi
			
		FRAMES=$(find ${TMP} -name "*.dng" | wc -l)
	fi
	
	
#Dual ISO Conversion
	if [ $DUAL_ISO == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Combining Dual ISO...\n"
		
		#Original DNGs will be moved here.
		oldFiles="${TMP}/orig_dng"
		mkdirS $oldFiles
		
		#Prepare for parallelism.
		lPath="${TMP}/devel.lock"
		iPath="${TMP}/iCount"
		touch $iPath
		echo "" >> $iPath #Increment the count. 0 lines is uncountable
		
		inc_iso() { #7 args: {} $CR_HDR $TMP $FRAMES $oldFiles $lPath $iPath. {} is a path. Progress is thread safe.
			$2 $1 --no-cs >/dev/null 2>/dev/null #The LQ option, --mean23, is completely unusable in my opinion.
			
			name=$(basename "$1")
			mv "${3}/${name%.*}.dng" $5 #Move away original dngs.
			mv "${3}/${name%.*}.DNG" "${3}/${name%.*}.dng" #Rename *.DNG to *.dng.
			
			while true; do #This is the progress indicator. Don't use count to index the files; it won't correspond.
				if mkdir $6 2>/dev/null; then #Lock mechanism. If dir is made, true. If not, sleep. Suppress errors.
					count="$(wc -l < "${7}")" #Read the count from iPath.
					echo -e "\e[2K\rDual ISO Development: Frame ${count}/${4}\c"
					echo "" >> $7 #Increment the count by adding a line to iPath.
					rm -rf $6
					break
				else
					sleep 0.05
				fi
			done
		}
		
		export -f inc_iso #Must expose function to subprocess.
		
		find $TMP -name "*.dng" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 bash -c "inc_iso {} $CR_HDR $TMP $FRAMES $oldFiles $lPath $iPath"
		rm $iPath
		echo -e "\n"
	fi

#Get White Balance correction factor.
	if [ $GEN_WHITE == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating WB...\n"
		
		#Calculate n, the distance between samples.
		if [ $WHITE_SPD -gt $FRAMES ]; then
			WHITE_SPD=$FRAMES
		fi
		n=`echo "${FRAMES} / ${WHITE_SPD}" | bc`
		
		toBal="${TMP}/toBal"
		mkdirS $toBal
		
		#Develop every nth file for averaging.
		i=0
		t=0
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do 
			if [ `echo "(${i}+1) % ${n}" | bc` -eq 0 ]; then
				dcraw -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -o 0 -T "${file}"
				name=$(basename "$file")
				mv "$TMP/${name%.*}.tiff" $toBal #TIFF MOVEMENT. We use TIFFs here because it's easy for dcraw and Python.
				let t++
			fi
			echo -e "\e[2K\rWB Development: Sample ${t}/$(echo "${FRAMES} / $n" | bc) (Frame: $(echo "${i} + 1" | bc)/${FRAMES})\c"
			let i++
		done
		echo ""
		
		#Calculate + store result into a form dcraw likes.
		echo -e "Calculating Auto White Balance..."
		BALANCE=`$BAL $toBal`
		WHITE="-r ${BALANCE} 1.000000"
		echo -e "Correction Factor (RGB): ${BALANCE} 1.0\n"
		
	elif [ $CAMERA_WB == true ]; then
		echo -e "Retrieving Camera White Balance..."
		
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			#dcraw a single file verbosely, to get the camera multiplier with awk.
			BALANCE=`dcraw -T -w -v -c ${file} 2>&1 | awk '/multipliers/ { print $2, $3, $4 }'`
			break
		done
		WHITE="-r ${BALANCE} 1.0"
		echo -e "Correction Factor (RGB): ${BALANCE} 1.0\n"
	fi

#Move .wav.
	SOUND_PATH="${TMP}/${TRUNC_ARG}_.wav"
	
	if [ ! -f $SOUND_PATH ]; then
		echo -e "*Not moving .wav, because it doesn't exist.\n"
	else
		echo -e "*Moving .wav.\n"
		cp $SOUND_PATH $FILE
	fi
	
#DEFINE FUNCTIONS
		
	dcrawOpt() {
		find "${TMP}" -maxdepth 1 -iname '*.dng' -print0 | sort -z | xargs -0 \
			dcraw -c -q $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH
	} #Is prepared to pipe all the files in TMP outwards.
	
	mov_main() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -vcodec prores_ks -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $LUT $SOUND_ACTION "${VID}_hq.mov"
	} #-loglevel panic -stats
	
	mov_prox() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast -vf "scale=trunc(iw/2)*${SCALE}:trunc(ih/2)*${SCALE}" -crf 23 $LUT -c:a mp3 "${VID}_lq.mp4"
	} #The option -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.
	
	img_par() { #Takes 17 arguments: {} $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE $HIGHLIGHT_MODE $GAMMA $NOISE_REDUC $DEPTH $SEQ $TRUNC_ARG $IMG_FMT $FRAMES $DEPTH_OUT $COMPRESS $isJPG $PROXY_SCALE $PROXY
		count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Instead of count from file, count from name!
		if [ ${16} == true ]; then
			dcraw -c -q $2 $3 $4 $5 -H $6 -g $7 $8 -o 0 $9 $1 | \
				tee >(convert ${14} - ${15} $(printf "${10}/${11}_%06d.${12}" ${count})) | \
					convert - -quality 90 -resize ${17} $(printf "${18}/${11}_%06d.jpg" ${count})
			echo -e "\e[2K\rDNG to ${12^^}/JPG: Frame ${count^^}/${13}\c"
		else
			dcraw -c -q $2 $3 $4 $5 -H $6 -g $7 $8 -o 0 $9 $1 | \
				convert ${14} - ${15} $(printf "${10}/${11}_%06d.${12}" ${count})
			echo -e "\e[2K\rDNG to ${12^^}: Frame ${count^^}/${13}\c"
		fi
	}
	
	export -f img_par
	
	SEQ="${FILE}/${IMG_FMT}_${TRUNC_ARG}"
	PROXY="${FILE}/proxy_${TRUNC_ARG}"

#IMAGE PROCESSING
	if [ $IMAGES == true ] ; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Processing Image Sequence...\n"
		
#Define Image Directories, Create SEQ directory
		mkdirS $SEQ
		
		if [ $isJPG == true ]; then
			mkdirS $PROXY
		fi
		
#Define compression based on IMG_FMT
		if [ $isCOMPRESS == true ]; then
			if [ $IMG_FMT == "exr" ]; then
				COMPRESS="-compress piz"
			elif [ $IMG_FMT == "tiff" ]; then
				COMPRESS="-compress zip"
			elif [ $IMG_FMT == "png" ]; then
				COMPRESS="-quality 9"
			elif [ $IMG_FMT == "dpx" ]; then
				COMPRESS="-compress rle"
			fi #Compression modes are hardcoded.
		fi

#Convert all the actual DNGs to IMG_FMT, in parallel.
		find "${TMP}" -maxdepth 1 -name '*.dng' -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
			bash -c "img_par {} '$DEMO_MODE' '$FOUR_COLOR' '$BADPIXELS' '$WHITE' '$HIGHLIGHT_MODE' '$GAMMA' '$NOISE_REDUC' '$DEPTH' \
						'$SEQ' '$TRUNC_ARG' '$IMG_FMT' '$FRAMES' '$DEPTH_OUT' '$COMPRESS' '$isJPG' '$PROXY_SCALE' '$PROXY' \
					"
		
		if [ $isJPG == true ]; then #Make it print "Frame $FRAMES / $FRAMES" as the last output :).
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}/JPG: Frame ${FRAMES}/${FRAMES}\c"
		else
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}: Frame ${FRAMES}/${FRAMES}\c"
		fi
		
		echo -e "\n"
		
#Potentially apply a LUT.
		if [ $isLUT == true ]; then #Some way to package this into the development itself without piping hell?
			if [ $IMG_FMT == "exr" ]; then
				echo -e "*Cannot apply LUT to EXR sequences."
			else
				echo -e "\e[1m${TRUNC_ARG}:\e[0m Applying LUT to ${FRAMES} ${IMG_FMT^^}s...\n"
				
				lutLoc="${TMP}/lut_conv"
				mkdirS $lutLoc
				
				find $SEQ -name "*.${IMG_FMT}" | xargs -I '{}' mv {} "${lutLoc}"
				#~ mv "${SEQ}/*.${IMG_FMT}" "${TMP}/lut_conv" #Move back into tmp so it can be processed back out.
				ffmpeg -f image2 -i "${lutLoc}/${TRUNC_ARG}_%06d.${IMG_FMT}" -loglevel panic -stats -vf $LUT "${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT}"
				#ffmpeg doesn't like tiffs.
			fi
			#~ exit
		fi
	fi
	
#MOVIE PROCESSING
	VID="${FILE}/${TRUNC_ARG}"
	SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor for halved video, *2 for 50%
	
	SOUND="-i ${TMP}/${TRUNC_ARG}_.wav"
	SOUND_ACTION="-c:a mp3"
	if [ ! -f $SOUND_PATH ]; then
		SOUND=""
		SOUND_ACTION=""
	fi
	
	if [ $MOVIE == true ] && [ $IMAGES == false ]; then
		#LUT is automatically applied if argument was passed.
		if [ $isH264 == true ]; then
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes/H.264..."
			runSim dcrawOpt mov_main mov_prox
		else
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			dcrawOpt | mov_main
		fi
	elif [ $MOVIE == true ] && [ $IMAGES == true ]; then
		if [ $isH264 == true ]; then
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes/H.264..."
			runSim dcrawOpt mov_main mov_prox
		else
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			dcrawOpt | mov_main
		fi
	fi
	
	echo -e "\n\e[1mCleaning Up.\e[0m\n"
	
#Potentially move DNGs.
	if [ $KEEP_DNGS == true ]; then
		DNG="${FILE}/dng_${TRUNC_ARG}"
		mkdirS $DNG
		
		if [ $DUAL_ISO == true ]; then
			oldFiles="${TMP}/orig_dng"
			find $oldFiles -name "*.dng" | xargs -I '{}' mv {} $DNG #Preserve the original, unprocessed DNGs.
		else
			find $TMP -name "*.dng" | xargs -I '{}' mv {} $DNG
		fi
	fi
	
#Delete tmp
	rm -rf $TMP
	
	let ARGNUM--
done

exit 0

test() {
	bench() {
		first=`echo "$(date +%s%N | cut -b1-13) / 1000" | bc -l`
		$1
		end=`echo "($(date +%s%N | cut -b1-13) / 1000 ) - ${first}" | bc -l`
		echo $end
	} #Just a test :).
	
	#Old Image Development
		i=0 #Very important variable. See functions called.
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			if [ $isJPG == true ]; then
				runSim dcrawFile img_main img_prox
				echo -e "\e[2K\rDNG to ${IMG_FMT^^}/JPG (dcraw): Frame $(echo "${i} + 1" | bc)/${FRAMES}.\c"
			else
				dcrawFile $file | img_main
				echo -e "\e[2K\rDNG to ${IMG_FMT^^} (dcraw): Frame $(echo "${i} + 1" | bc)/${FRAMES}.\c"
			fi
			let i++
		done
	
	img_main() {
		convert $DEPTH_OUT - $COMPRESS $(printf "${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT}" $i) #Make sure to do deep analysis later.
		#Requires some variable i outside the scope of the function.
	}
	
	img_prox() {
		convert - -quality 90 -resize $PROXY_SCALE $(printf "${PROXY}/${TRUNC_ARG}_%06d.jpg" $i)
	} #-quiet
	
	dcrawFile() {
		dcraw -c -q $DEMO_MODE $FOUR_COLOR $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o 0 $DEPTH $file
		#Requires some file outside the scope of the function. Pipes that file.
	}
	
	#Prepare for parallelism.
		lPath="${TMP}/devel.lock"
		iPath="${TMP}/iCount"
		touch $iPath
		echo "" >> $iPath #Increment the count. 0 lines is uncountable.
		
	#Use mkdir $lPath in an if as a lock.
	
	cat $PIPE | vidLQ & echo "text" | tee $PIPE | vidHQ # Old method. Surprised it worked...
}
