#!/bin/bash

#UNFIXED BUG: Run on all Charleston files; determine what makes -k non-numeric...

#EXPERIMENT:
#~ ../../mlv_dump -o test/test 700D_mv1080_1728x1158.MLV --dng --no-cs
#~ readarray -t y <<<`../../mlv_dump -v -m 700D_mv1080_1728x1158.MLV | grep 'Gain [RGB]' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1-3`


#~ The MIT License (MIT)

#~ Copyright (c) 2016 Sofus Rose

#~ Permission is hereby granted, free of charge, to any person obtaining a copy
#~ of this software and associated documentation files (the "Software"), to deal
#~ in the Software without restriction, including without limitation the rights
#~ to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#~ copies of the Software, and to permit persons to whom the Software is
#~ furnished to do so, subject to the following conditions:
#~ 
#~ The above copyright notice and this permission notice shall be included in all
#~ copies or substantial portions of the Software.
#~ 
#~ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#~ IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#~ FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#~ AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#~ LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#~ OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#~ SOFTWARE.

#BASIC VARS
VERSION="1.8.1" #Version string.
THREADS=8

#DEPENDENCIES
DEB_DEPS="imagemagick dcraw ffmpeg python3 python3-pip exiftool" #Dependency package names (Debian). List with -K option.
PIP_DEPS="numpy Pillow tifffile" #Technically, you don't need Pillow. I'm not really sure :).
MAN_DEPS="mlv_dump raw2dng cr2hdr mlv2badpixels.sh balance.py"
PYTHON="python3"

#PATHS
MLV_DUMP="./mlv_dump" #Path to mlv_dump location.
RAW_DUMP="./raw2dng" #Path to raw2dng location.
CR_HDR="./cr2hdr" #Path to cr2hdr location.
MLV_BP="./mlv2badpixels.sh"
PYTHON_BAL="./balance.py"
BAL="${PYTHON} ${PYTHON_BAL}"
OUTDIR="$(pwd)/raw_conv"
isOutGen=false

#OUTPUT
MOVIE=false
FPS=24 #Will be read from .MLV or .RAW.
IMAGES=false
IMG_FMT="exr"
COMPRESS=""
isCOMPRESS=false
isJPG=false
isH264=false
KEEP_DNGS=false

#FRAME RANGE
FRAME_RANGE="" #UPDATED LATER WHEN FRAME # IS AVAILABLE.
FRAME_START="1"
FRAME_END=""
isFR=true

#RAW DEVELOPOMENT
HIGHLIGHT_MODE="0"
PROXY_SCALE="50%"
DEMO_MODE="1"
GAMMA="1 1"
SPACE="0" #Color Space. Correlates to Gamma.
DEPTH="-W -6"
DEPTH_OUT="-depth 16"
NOISE_REDUC=""
FOUR_COLOR=""
CHROMA_SMOOTH="--no-cs"

#FEATURES
DUAL_ISO=false
BADPIXELS=""
BADPIXEL_PATH=""
isBP=false
DARKFRAME=""
SETTINGS_OUTPUT=false
BLACK_LEVEL=""

#White Balance
WHITE=""
GEN_WHITE=false
CAMERA_WB=true
WHITE_SPD=15

#LUT
LUT=""
isLUT=false

help() {
cat << EOF
Usage:
	$(echo -e "\033[1m./convmlv.sh\033[0m [OPTIONS] \033[2mmlv_files\033[0m")
	
INFO:
	A script allowing you to convert .MLV, .RAW, or a folder with a DNG sequence into a sequence/movie with optional proxies. Images
	are auto compressed. Many useful options are exposed, including formats (EXR by default).
	
$(echo -e "VERSION: ${VERSION}")
	
DEPENDENCIES: If you don't use a feature, you don't need the dependency, though it's best to download them all.
	-mlv_dump: For DNG extraction from MLV. http://www.magiclantern.fm/forum/index.php?topic=7122.0
	-raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0
	-mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src
	-dcraw: For RAW development.
	-ffmpeg: For video creation.
	-ImageMagick: Used for making proxy sequence.
	-Python 3 + libs: Used for auto white balance.
	-exiftool: Used in mlv2badpixels.sh.


OPTIONS, BASIC:
	-v   version - Print out version string.
	-o<path>   OUTDIR - The path in which files will be placed (no space btwn -o and path).
	-M<path>   MLV_DUMP - The path to mlv_dump (no space btwn -M and path). Default is './mlv_dump'.
	-R<path>   RAW_DUMP - The path to raw2dng (no space btwn -M and path). Default is './raw2dng'.
	-y<path>   PYTHON - The path or command used to invoke Python. Defaults to python3.
	-B<path>   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'.
	
	-T[int]    Max process threads, for multithreaded parts of the program. Defaults to 8.
	
	
OPTIONS, OUTPUT:
	-i   IMAGE - Specify to create an image sequence (EXR by default).
	
	-f[0:3]   IMG_FMT - Create a sequence of <format> format. 0 is default.
	  --> 0: EXR (default), 1: TIFF, 2: PNG, 3: Cineon (DPX)."

	-c   COMPRESS - Specify to turn ***off*** automatic image compression. Auto compression options otherwise used:
	  --> TIFF: ZIP (best for 16-bit), PIZ for EXR (best for grainy images), PNG: lvl 9 (zlib deflate), DPX: RLE.
	  --> EXR's piz compression tends to be fastest + best.
	
	-m   MOVIE - Specify to create a Prores4444 video.
	
	-p[0:3]   PROXY - Specifies the proxy mode. 0 is default.
	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.
	  --> JPG proxy won't be developed w/o -i. H.264 proxy will be developed no matter what, if specified.
	
	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output.
	  --> Use -s<percentage>% (no space). 50% is default.
	
	-k   KEEP_DNGS - Specify if you want to keep the DNG files.
	  --> If you run convmlv on the dng_<name> folder, you will reuse those DNGs - no need to redevelop!
	  
	-E<range>   FRAME_RANGE - Specify to process only this frame range.
	  --> DNGs will still all be generated. Use -k to reuse a previous iteration to get past this!
	  --> <range> must be written as <start>-<end>, indexed from 0 to (# of frames - 1).
	  --> If you write a single number, only that frame will be developed.
	
	
OPTIONS, RAW DEVELOPMENT:
	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default.
	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.
	
	-r   FOUR_COLOR - Interpolate as four colors. Can often fix weirdness with VNG/AHD.
	
	-H[0:9]   HIGHLIGHT_MODE - 2 looks the best, but can break. 0 is a safe bet.
	  --> Use -H<number> (no space). 0 clips. 1 allows colored highlights. 2 adjusts highlights to grey.
	  --> 3 through 9 do highlight reconstruction with a certain tone. See dcraw documentation.
	
	-C[0:3]   CHROMA_SMOOTH - Apply chroma smoothing to the footage, which may help ex. with noise/bad pixels.
	  --> 0: None (default). 1: 2x2. 2: 3x3. 3: 5x5.
	  --> Only applied to .MLV files.
	
	-n[int]   NOISE_REDUC - This is the threshold of wavelet denoising - specify to use.
	  --> Use -n<number>. Defaults to no denoising. 150 tends to be a good setting; 350 starts to look strange.
	
	-g[0:4]   SPACE - This is output color space. 0 is default.
	  --> Use -g<mode> (no space). 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.
	
	-S   SHALLOW - Specifying this option will create an 8-bit output instead of a 16-bit output.
	  --> It'll kind of ruin the point of RAW, though....
	
	
OPTIONS, COLOR:
	-w[0:2]   WHITE - This is a modal white balance setting. Defaults to 0. 1 doesn't always work very well.
	  --> Use -w<mode> (no space).
	  --> 0: Auto WB (Requires Python Deps). 1: Camera WB. 2: No Change.
	
	-A[int]   WHITE_SPD - This is the amount of samples from which AWB will be calculated.
	  -->About this many frames, averaged over the course of the sequence, will be used to do AWB.
	
	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it.
	  --> Compatibility determined by ffmpeg (.cube is supported).
	  --> LUT cannot be applied to EXR sequences.
	  --> Path to LUT (no space between -l and path).
	
	
OPTIONS, FEATURES:
	-u    DUAL_ISO - Process file as dual ISO.
	
	-b   BADPIXELS - Fix focus pixels issue using dfort's script.
	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src.
	
	-a<path>   BADPIXEL_PATH - Use, appending to the generated one, your own .badpixels file.
	  --> Use -a<path> (no space). How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686
	
	-F<path>   DARKFRAME - This is the path to the dark frame MLV, for noise reduction.
	  --> This is a noise reduction technique: Record 5 sec w/lens cap on & same settings as footage.
	  --> Pass in that MLV file (not .RAW) as <path> to get noise reduction on all passed MLV files.
	  --> If the file extension is '.darkframe', the file will be used as the preaveraged dark frame.
	
	
OPTIONS, INFO:
	-e   Output MLV settings.

	-K   Debian Package Deps - Lists dependecies. Works with apt-get on Debian; should be similar elsewhere.
	  --> No operations will be done.
	  --> Example: sudo apt-get install $ (./convmlv -K)
	
	-Y   Python Deps - Lists Python dependencies. Works with pip.
	  --> No operations will be done. 
	  --> Example: sudo pip3 install $ (./convmlv -Y)
	
	-N  Manual Deps - Lists manual dependencies, which must be downloaded by hand.
	  --> There's no automatic way to install these. See the forum post.
	
EOF
}

mkdirS() {
	path=$1
	cleanup=$2
	cont=false
		
	if [ -d $path ]; then
		while true; do
			read -p "Overwrite ${path}? [y/n] " yn
			case $yn in
				[Yy]* ) echo -e ""; rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
				;;
				[Nn]* ) echo -e "\n\e[0;31m\e[1mDirectory ${path} won't be created.\e[0m\n"; cont=true; `$cleanup`; break
				;;
				* ) echo -e "\e[0;31m\e[1mPlease answer yes or no.\e[0m\n"
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

parseArgs() { #Fixing this would be difficult.
	if [ ${ARG} == "-e" ]; then #This very special arguments would fuck everything up if left to roam free...
		SETTINGS_OUTPUT=true
		let ARGNUM--
		continue
	fi
	if [ `echo "${ARG}" | cut -c1-1` = "-" ]; then
		if [ `echo "${ARG}" | cut -c2-2` = "H" ]; then
			HIGHLIGHT_MODE=`echo "${ARG}" | cut -c3-3`
			let ARGNUM--
		fi
		if [ `echo "${ARG}" | cut -c2-2` = "s" ]; then
			PROXY_SCALE=`echo "${ARG}" | cut -c3-${#ARG} >/dev/null 2>/dev/null` #Might error. We'll check, no worries.
			if [ -z $PROXY_SCALE ]; then
				echo -e "\e[0;31m\e[1mNo proxy scale set!\e[0m\n"
				exit 1
			fi
			let ARGNUM--
		fi
		#~ if [ `echo "${ARG}" | cut -c2-2` = "e" ]; then
			#~ SETTINGS_OUTPUT=true
			#~ let ARGNUM--
		#~ fi
		if [ `echo ${ARG} | cut -c2-2` = "u" ]; then
			DUAL_ISO=true
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "E" ]; then
			base=$(echo ${ARG} | cut -c3-${#ARG})
			FRAME_RANGE="$(echo "$(echo $base | cut -d"-" -f1) + 1" | bc)-$(echo "$(echo $base | cut -d"-" -f2) + 1" | bc)"
			FRAME_START=$(echo ${FRAME_RANGE} | cut -d"-" -f1)
			FRAME_END=$(echo ${FRAME_RANGE} | cut -d"-" -f2)
			isFR=false
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
		if [ `echo ${ARG} | cut -c2-2` = "C" ]; then
			mode=`echo ${ARG} | cut -c3-3`
			case ${mode} in
				"0") CHROMA_SMOOTH="--no-cs"
				;;
				"1") CHROMA_SMOOTH="--cs2x2"
				;;
				"2") CHROMA_SMOOTH="--cs3x3"
				;;
				"3") CHROMA_SMOOTH="--cs5x5"
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
				"0") GAMMA="1 1"; SPACE="0"
				;;
				"1") GAMMA="2.2 0"; SPACE="2"
				;;
				"2") GAMMA="1.8 0"; SPACE="4"
				;;
				"3") GAMMA="2.4 12.9"; SPACE="1"
				;;
				"4") GAMMA="2.222 4.5"; SPACE="0"
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
				"2") WHITE="-r 1 1 1 1"; CAMERA_WB=false; GEN_WHITE=false
				;;
			esac
		
			let ARGNUM--
		fi
		if [ `echo ${ARG} | cut -c2-2` = "K" ]; then
			echo $DEB_DEPS
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
		if [ `echo ${ARG} | cut -c2-2` = "N" ]; then
			echo $MAN_DEPS
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
		
		if [ ! -d $ARG ] && [ $(echo $(wc -c ${ARG} | cut -d " " -f1) / 1000 | bc) -lt 1000 ]; then #Check that the file is not too small.
			cont=false
			while true; do
				read -p "${ARG} is unusually small at $(wc -c ${ARG})KB. Continue, skip, or remove? [c/s/r] " csr
				case $ysr in
					[Cc]* ) "\n\e[0;31m\e[1mContinuing.\e[0m\n"; break
					;;
					[Ss]* ) echo -e "\n\e[0;31m\e[1mSkipping.\e[0m\n"; cont=true; break
					;;
					[Rr]* ) echo -e "\n\e[0;31m\e[1mRemoving ${ARG}.\e[0m\n"; cont=true; rm $ARG; break
					;;
					* ) echo -e "\e[0;31m\e[1mPlease answer continue, skip, or remove.\e[0m\n"
					;;
				esac
			done
			
			if [ $cont == true ]; then
				continue
			fi
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

bold() {
	echo -e "\e[1m${1}\e[0m"
}

prntSet() {
	cat << EOF
$(bold CameraName): ${CAM_NAME}
$(bold RecordingDate): ${REC_DATE}
$(bold RecordingTime): ${REC_TIME}

$(bold FPS): ${FPS}
$(bold TotalFrames): ${FRAMES}

$(bold Aperture): ${APERTURE}
$(bold ISO): ${ISO}
$(bold ShutterSpeed): ${SHUTTER}
$(bold WBKelvin): ${KELVIN}

$(bold FocalLength): ${LEN_FOCAL}
	
EOF
}

mlvSet() {
	FPS=`${MLV_DUMP} -v -m ${ARG} | grep FPS | awk 'FNR == 1 {print $3}'`
			
	CAM_NAME=`${MLV_DUMP} -v -m ${ARG} | grep 'Camera Name' | cut -d "'" -f 2`
	FRAMES=`${MLV_DUMP} -v -m ${ARG} | grep 'Frames Video' | sed 's/[[:alpha:] ]*: //' | cut -d$'\n' -f1`
	ISO=`${MLV_DUMP} -v -m ${ARG} | grep 'ISO' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f2`
	APERTURE=`${MLV_DUMP} -v -m ${ARG} | grep 'Aperture' | sed 's/[[:alpha:] ]*:    //' | cut -d$'\n' -f1`
	LEN_FOCAL=`${MLV_DUMP} -v -m ${ARG} | grep 'Focal Len' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
	SHUTTER=`${MLV_DUMP} -v -m ${ARG} | grep 'Shutter' | sed 's/[[:alpha:] ]*:   //' | grep -oP '\(\K[^)]+' |  cut -d$'\n' -f1`
	REC_DATE=`${MLV_DUMP} -v -m ${ARG} | grep 'Date' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	REC_TIME=`${MLV_DUMP} -v -m ${ARG} | grep 'Time:        [0-2][0-9]\:*' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	KELVIN=`${MLV_DUMP} -v -m ${ARG} | grep 'Kelvin' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
}

if [ $# == 0 ]; then
	help
	echo -e "\e[0;31m\e[1mNo arguments, no joy!!!\e[0m\n"
fi

ARGNUM=$#
for ARG in $*; do
#Evaluate command line arguments. ARGNUM decrements to keep track of how many files there are to process.
	parseArgs # <-- Has a continue statement inside of it if we haven't reached the output.
#Check that things exist.
	checkDeps
	
#The Very Basics
	BASE="$(basename "$ARG")"
	EXT="${BASE##*.}"
	TRUNC_ARG="${BASE%.*}"

#Potentially Print Settings
	if [ $SETTINGS_OUTPUT == true ]; then
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			# Read the header for interesting settings :) .
			mlvSet
			
			echo -e "\n\e[1m\e[0;32m\e[1mFile\e[0m\e[0m: ${ARG}\n"
			prntSet
			continue
		else
			echo -e "Cannot print settings from ${ARG}; it's not an MLV file!"
		fi
	fi
	
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

#Establish Basic Directory Structure.
	if [ $OUTDIR != $PWD ] && [ isOutGen == false ]; then
		mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP.
		isOutGen=true
	fi
	
	FILE="${OUTDIR}/${TRUNC_ARG}"
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	
#Manage DNG argument/Create FILE and TMP.
	DEVELOP=true
	if [ -d $ARG ] && [ `basename ${ARG} | cut -c1-3` == "dng" ] && [ -f "${ARG}/../settings.txt" ]; then #If we're reusing a dng sequence, copy over before we delete the original.
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Moving DNGs from previous run...\n" #Use prespecified DNG sequence.
		
		DNG_LOC=${OUTDIR}/tmp_reused
		mkdir -p ${OUTDIR}/tmp_reused
		
		find $ARG -iname "*.dng" | xargs -I {} mv {} $DNG_LOC #Copying DNGs to temporary location.
		
		FPS=`cat ${ARG}/../settings.txt | grep "FPS" | cut -d $" " -f2` #Grab FPS from previous run.
		FRAMES=`cat ${ARG}/../settings.txt | grep "Frames" | cut -d $" " -f2` #Grab FRAMES from previous run.
		cp "${ARG}/../settings.txt" $DNG_LOC
		
		TRUNC_ARG=`echo $TRUNC_ARG | cut -c5-${#TRUNC_ARG}`
		oldARG=$ARG
		ARG=$(dirname $ARG)/${TRUNC_ARG}
		BASE="$(basename "$ARG")"
		EXT="${BASE##*.}"		
		
		dngLocClean() {
			find $DNG_LOC -iname "*.dng" | xargs -I {} mv {} $oldARG
			rm -rf $DNG_LOC
		}
		
		FILE="${OUTDIR}/${TRUNC_ARG}"
		TMP="${FILE}/tmp_${TRUNC_ARG}" #Remove dng_ from ARG by redefining basic constants. Ready to go!
		
		mkdirS $FILE dngLocClean
		mkdirS $TMP #Make the folders.
		
		find $DNG_LOC -iname "*.dng" | xargs -I {} mv {} $TMP #Moving files to where they need to go.
		cp "${DNG_LOC}/settings.txt" $FILE
		
		DEVELOP=false
		rm -r $DNG_LOC
	elif [ -d $ARG ]; then #If it's a DNG sequence, but not a reused one.
		mkdirS $FILE
		mkdirS $TMP
		
		FPS=24 #Set it to a safe default.
		
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Using specified folder of RAW sequences...\n" #Use prespecified DNG sequence.
		find $ARG -iname "*.dng" | xargs -I {} cp {} $TMP #Copying DNGs to TMP.
		
		FRAMES=$(find ${TMP} -name "*.dng" | wc -l)
	else
		mkdirS $FILE
		mkdirS $TMP
	fi
	
#Darkframe Averaging
	if [ ! $DARKFRAME == "" ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Creating darkframe for subtraction...\n"
		
		avgFrame="${TMP}/avg.darkframe" #The path to the averaged darkframe file.
		
		darkBase="$(basename "$ARG")"
		darkExt="${BASE##*.}"
		
		if [ darkExt != 'darkframe' ]; then
			$MLV_DUMP -o "${avgFrame}" -a $DARKFRAME >/dev/null 2>/dev/null
		else
			cp $DARKFRAME $avgFrame #Copy the preaveraged frame if the extension is .darkframe.
		fi
		
		DARK_PROC="-s ${avgFrame}"
	fi
	
#Dump to/use DNG sequence, perhaps subtracting darkframe.
	if [ $DEVELOP == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Dumping to DNG Sequence...\n"
				
		if [ ! $DARKFRAME == "" ] && [ ! $CHROMA_SMOOTH == "--no-cs" ]; then #Just to let the user know that certain features are impossible with RAW.
			rawStat="*Skipping Darkframe subtraction and Chroma Smoothing for RAW file ${TRUNC_ARG}."
		elif [ ! $DARKFRAME == "" ]; then
			rawStat="*Skipping Darkframe subtraction for RAW file ${TRUNC_ARG}."
		elif [ ! $CHROMA_SMOOTH == "--no-cs" ]; then
			rawStat="*Skipping Chroma Smoothing for RAW file ${TRUNC_ARG}."
		else
			rawStat="\c"
		fi
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			# Read the header for interesting settings :) .
			mlvSet
			
			prntSet > $FILE/settings.txt
			sed -i -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $FILE/settings.txt #Strip escape sequences.
			
			#Dual ISO might want to do the chroma smoothing.
			if [ $DUAL_ISO == true ]; then
				smooth=""
			else
				smooth=$CHROMA_SMOOTH
			fi
			
			$MLV_DUMP $ARG $DARK_PROC -o "${TMP}/${TRUNC_ARG}_" --dng $smooth >/dev/null 2>/dev/null
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			echo -e $rawStat
			FPS=`$RAW_DUMP $ARG "${TMP}/${TRUNC_ARG}_" | awk '/FPS/ { print $3; }'` #Run the dump while awking for the FPS.
		fi
			
		FRAMES=$(find ${TMP} -name "*.dng" | wc -l) #Backup
		
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START - 1" | bc)).dng)
	fi
	
	BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START - 1" | bc)).dng) #Use the first DNG to get the correct black level.

#Create badpixels file.
	if [ $isBP == true ] && [ ! -d $DNG_LOC ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating badpixels file...\n"
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		gen_bad="${TMP}/${bad_name}"
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			$MLV_BP -o $gen_bad $ARG
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			$MLV_BP -o $gen_bad $ARG
		fi
		
		if [[ ! -z $BADPIXEL_PATH ]]; then
			if [ -f "${TMP}/${bad_name}" ]; then
				echo -e "\e[1m${TRUNC_ARG}:\e[0m Concatenating with specified badpixels file...\n"
				mv "${TMP}/${bad_name}" "${TMP}/bp_gen"
				cp $BADPIXEL_PATH "${TMP}/bp_imp"
				
				{ cat "${TMP}/bp_gen" && cat "${TMP}/bp_imp"; } > "${TMP}/${bad_name}" #Combine specified file with the generated file.
			else
				cp $BADPIXEL_PATH "${TMP}/${bad_name}"
			fi
		fi
		
		BADPIXELS="-P ${gen_bad}"
	elif [[ ! -z $BADPIXEL_PATH ]]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Using specified badpixels file...\n"
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		gen_bad="${TMP}/${bad_name}"
		cp $BADPIXEL_PATH "${gen_bad}"
		BADPIXELS="-P ${gen_bad}"
		#~ echo $gen_bad
	fi
	
	if [ $isFR == true ]; then #Ensure that FRAME_RANGE is set.
		FRAME_RANGE="1-${FRAMES}"
		FRAME_START="1"
		FRAME_END=$FRAMES
	fi

#Dual ISO Conversion
	if [ $DUAL_ISO == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Combining Dual ISO...\n"
		
		#Original DNGs will be moved here.
		oldFiles="${TMP}/orig_dng"
		mkdirS $oldFiles
		
		inc_iso() { #6 args: 1{} 2$CR_HDR 3$TMP 4$FRAMES 5$oldFiles 6$CHROMA_SMOOTH. {} is a path. Progress is thread safe. Experiment gone right :).
			count=$(echo "$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) + 1" | bc) #Get count from filename.
			
			$2 $1 $6 >/dev/null 2>/dev/null #The LQ option, --mean23, is completely unusable in my opinion.
			
			name=$(basename "$1")
			mv "${3}/${name%.*}.dng" $5 #Move away original dngs.
			mv "${3}/${name%.*}.DNG" "${3}/${name%.*}.dng" #Rename *.DNG to *.dng.
			
			echo -e "\e[2K\rDual ISO Development: Frame ${count}/${4}\c"
		}
		
		export -f inc_iso #Must expose function to subprocess.
		
		find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | cut -d '' --complement -f $FRAME_RANGE | tr -d '\n' | xargs -0 -I {} -n 1 mv {} $oldFiles #Move all the others to correct position.
		find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 bash -c "inc_iso '{}' '$CR_HDR' '$TMP' '$FRAMES' '$oldFiles' '$CHROMA_SMOOTH'"
		
		FRAME_RANGE="1-${FRAMES}"
		
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START - 1" | bc)).dng) #Use the first DNG to get the correct black level.

		echo -e "\n"
	fi
	
	echo -e "BlackLevel: ${BLACK_LEVEL}" >> $FILE/settings.txt #Black level must now be set.

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
				dcraw -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -o $SPACE -T "${file}"
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
		echo -e "Correction Factor (RGBG): ${BALANCE} 1.000000\n"
		
	elif [ $CAMERA_WB == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Retrieving Camera White Balance..."
		
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			#dcraw a single file verbosely, to get the camera multiplier with awk.
			BALANCE=`dcraw -T -w -v -c ${file} 2>&1 | awk '/multipliers/ { print $2, $3, $4 }'`
			break
		done
		WHITE="-r ${BALANCE} 1.0"
		echo -e "Correction Factor (RGBG): ${BALANCE} 1.000000\n"
	else
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Ignoring White Balance..."
		echo -e "Correction Factor (RGBG): 1.000000 1.000000 1.000000 1.000000\n"
	fi

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
		find "${TMP}" -maxdepth 1 -iname "*.dng" -print0 | sort -z | cut -d '' -f $FRAME_RANGE | tr -d "\n" | xargs -0 \
			dcraw -c -q $DEMO_MODE $FOUR_COLOR -k $BLACK_LEVEL $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $NOISE_REDUC -o $SPACE $DEPTH
	} #Is prepared to pipe all the files in TMP outwards.
	
	dcrawImg() { #Find and splay image sequence data as ppm, ready to be processed by ffmpeg.
		find "${SEQ}" -maxdepth 1 -iname "*.${IMG_FMT}" -print0 | sort -z | xargs -0 -I {} convert '{}' ppm:-
	} #Finds all images, prints to stdout quickly without any operations using convert.
	
	mov_main() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -vcodec prores_ks -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $LUT $SOUND_ACTION "${VID}_hq.mov"
	} #-loglevel panic -stats
	
	mov_prox() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast -vf "scale=trunc(iw/2)*${SCALE}:trunc(ih/2)*${SCALE}" -crf 23 $LUT -c:a mp3 "${VID}_lq.mp4"
	} #The option -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" fixes when x264 is unhappy about non-2 divisible dimensions.
	
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
	
	img_par() { #Takes 20 arguments: {} 2$DEMO_MODE 3$FOUR_COLOR 4$BADPIXELS 5$WHITE 6$HIGHLIGHT_MODE 7$GAMMA 8$NOISE_REDUC 9$DEPTH 10$SEQ 11$TRUNC_ARG 12$IMG_FMT 13$FRAMES 14$DEPTH_OUT 15$COMPRESS 16$isJPG 17$PROXY_SCALE 18$PROXY 19$BLACK_LEVEL 20$SPACE
		count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Instead of count from file, count from name!
		if [ ${16} == true ]; then
			dcraw -c -q $2 $3 $4 $5 -H $6 -k ${19} -g $7 $8 -o ${20} $9 $1 | \
				tee >(convert ${14} - ${15} $(printf "${10}/${11}_%06d.${12}" ${count})) | \
					convert - -quality 90 -resize ${17} $(printf "${18}/${11}_%06d.jpg" ${count})
			echo -e "\e[2K\rDNG to ${12^^}/JPG: Frame ${count^^}/${13}\c"
		else
			dcraw -c -q $2 $3 $4 $5 -H $6 -k ${19} -g $7 $8 -o ${20} $9 $1 | \
				convert ${14} - ${15} $(printf "${10}/${11}_%06d.${12}" ${count})
			echo -e "\e[2K\rDNG to ${12^^}: Frame ${count^^}/${13}\c"
		fi
	}
	
	export -f img_par
	
	
#PROCESSING

#IMAGE PROCESSING
	if [ $IMAGES == true ] ; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Processing Image Sequence...\n"
		
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
				COMPRESS="-quality 9"
			elif [ $IMG_FMT == "dpx" ]; then
				COMPRESS="-compress rle"
			fi
		fi

#Convert all the actual DNGs to IMG_FMT, in parallel.
		find "${TMP}" -maxdepth 1 -name '*.dng' -print0 | sort -z | cut -d '' -f $FRAME_RANGE | tr -d "\n" | xargs -0 -I {} -P $THREADS -n 1 \
			bash -c "img_par '{}' '$DEMO_MODE' '$FOUR_COLOR' '$BADPIXELS' '$WHITE' '$HIGHLIGHT_MODE' '$GAMMA' '$NOISE_REDUC' '$DEPTH' \
						'$SEQ' '$TRUNC_ARG' '$IMG_FMT' '$FRAMES' '$DEPTH_OUT' '$COMPRESS' '$isJPG' '$PROXY_SCALE' '$PROXY' '$BLACK_LEVEL' '$SPACE'\
					"

		if [ $isJPG == true ]; then #Make it print "Frame $FRAMES / $FRAMES" as the last output :).
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}/JPG: Frame ${FRAME_END}/${FRAMES}\c"
		else
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}: Frame ${FRAME_END}/${FRAMES}\c"
		fi
		
		echo -e "\n"
		
#Apply a LUT to non-EXR images.
		if [ $isLUT == true ]; then #Some way to package this into the development itself without piping hell?
			if [ $IMG_FMT == "exr" ]; then
				echo -e "*Cannot apply LUT to EXR sequences."
			else
				echo -e "\e[1m${TRUNC_ARG}:\e[0m Applying LUT to ${FRAMES} ${IMG_FMT^^}s...\n"
				
				lutLoc="${TMP}/lut_conv"
				mkdirS $lutLoc
				
				find $SEQ -name "*.${IMG_FMT}" -print0 | cut -d '' -f $FRAME_RANGE | tr -d "\n" | xargs -0 -I '{}' mv {} "${lutLoc}"
				ffmpeg -f image2 -i "${lutLoc}/${TRUNC_ARG}_%06d.${IMG_FMT}" -loglevel panic -stats -vf $LUT "${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT}"
			fi
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
	elif [ $MOVIE == true ] && [ $IMAGES == true ]; then #Use images if available, as opposed to developing the files again.
		if [ $isH264 == true ]; then
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes/H.264..."
			runSim dcrawImg mov_main mov_prox
		else
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			dcrawImg | mov_main
		fi
	fi
	
	if [ $MOVIE == false ] && [ $isH264 == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to H.264..."
		if [ $IMAGES == true ]; then
			dcrawImg | mov_prox
		else
			dcrawOpt | mov_prox
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
