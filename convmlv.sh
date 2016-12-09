#!/bin/bash

#desc: Main file - uses convmlv components as needed.

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

VERSION="2.1.0a3" #Version string.
INPUT_ARGS=$(echo "$@") #The original input argument string.

if [ $# == 0 ]; then #No given arguments.
	echo -e "\033[0;31m\033[1mNo arguments given.\033[0m\n\tType 'convmlv -h/--help' to see help page, or 'convmlv -v/--version' for current version string."
fi

#BASIC FUNCTIONS

#NOTE: How to use a nested array in an associative array:
# declare -a outArray=${assocArray[key]}

#NOTE: How to place nested array in an associative array:
# assocArray[key]="( \"hello\" \"world\" )". Notice the escaped internal "".

readlinkF() { #readlink -f, but works on all platforms (including mac).
	target=$1
	
	if [[ $OSTYPE == "linux-gnu" ]]; then #Linux-specific constants.
		echo $(readlink -f "$target")
	elif [[ $OSTYPE == "darwin11" ]]; then #Mac-specific constants
		cd `dirname $target`
		target=`basename $target`

		# Iterate down a (possible) chain of symlinks
		while [ -L "$target" ]; do
			target=`readlink $target`
			cd `dirname $target`
			target=`basename $target`
		done

		# Compute the canonicalized name by finding the physical path
		# for the directory we're in and appending the target file.
		phys=`pwd -P`
		res=$phys/$target
		echo $res
	fi
}

setPaths() { #Repends on SRC_PATH, BIN_PATH, and PYTHON. Run this function if either is changed.
	MLV_DUMP="${BIN_PATH}/mlv_dump" #Path to mlv_dump location.
	RAW_DUMP="${BIN_PATH}/raw2dng" #Path to raw2dng location.
	CR_HDR="${BIN_PATH}/cr2hdr" #Path to cr2hdr location.
	MLV_BP="${BIN_PATH}/mlv2badpixels.sh"
	PYTHON_BAL="${SRC_PATH}/imgProcessing/balance.py"
	PYTHON_SRANGE="${SRC_PATH}/imgProcessing/sRange.py"
	BAL="${PYTHON} ${PYTHON_BAL}"
	SRANGE="${PYTHON} ${PYTHON_SRANGE}"
	COLOR_LUTS=("${SCRIPT_LOCATION}/color-core" "${SCRIPT_LOCATION}/color-ext") #One can add more with options, but these are the defaults.
	
	DCRAW="dcraw"
	
	#new array method
#BINARY PATHS
	SETTINGS[bin_mlvdump]="${SETTINGS[path_bin]}/mlv_dump" #Path to mlv_dump location.
	SETTINGS[bin_rawdump]="${SETTINGS[path_bin]}/raw2dng" #Path to raw2dng location.
	SETTINGS[bin_cr2hdr]="${SETTINGS[path_bin]}/cr2hdr" #Path to cr2hdr location.
	SETTINGS[bin_mlv2badpixels]="${SETTINGS[path_bin]}/mlv2badpixels.sh"
	SETTINGS[bin_dcraw]="dcraw"
	
#PYTHON PATHS
	SETTINGS[bin_python_balance]="${SETTINGS[path_src]}/imgProcessing/balance.py"
	SETTINGS[bin_python_sRange]="${SETTINGS[path_src]}/imgProcessing/sRange.py"
	
	SETTINGS[bin_balance]="${SETTINGS[path_python]} ${SETTINGS[bin_python_balance]}"
	SETTINGS[bin_sRange]="${SETTINGS[path_python]} ${SETTINGS[bin_python_sRange]}"
	
#COLOR PATHS
	SETTINGS[col_lutList]="( \"${SETTINGS[path_script]}/color-core\" \"${SETTINGS[path_script]}/color-ext\" )" #One can add more with options, but these are the defaults.
}

setDefaults() { #Set all the default global variables. Run during "parseAll".
	
#SETTINGS ARRAY GENERATION
	unset SETTINGS
	declare -g SETTINGS
	
#DEPENDENCIES
	DEB_DEPS="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl libc6-i386" #Dependency package names (Debian). List with -K option.
	UBU_DEPS="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl libc6-i386" #Dependency package names (Ubuntu). List with -K option.
	FED_DEPS="ImageMagick dcraw ffmpeg python3 python-pip perl-Image-ExifTool glibc-devel.i686" #Dependency package names (Fedora). List with -K option.
	BREW_DEPS="imagemagick dcraw ffmpeg python3 exiftool"
	
	PIP_DEPS="numpy tifffile" #You don't need Pillow. That's just to make balance.py a bit more portable.
	MAN_DEPS="mlv_dump raw2dng cr2hdr mlv2badpixels.sh balance.py sRange.py color-core"
	if [[ $OSTYPE == "linux-gnu" ]]; then
		PYTHON="python3"
	elif [[ $OSTYPE == "darwin11" ]]; then
		PYTHON="python3"
	else
		PYTHON="python"
	fi
	
	#new array method
	SETTINGS[deps_deb]="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl libc6-i386" #Dependency package names (Debian). List with -K option.
	SETTINGS[deps_ubu]="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl libc6-i386" #Dependency package names (Ubuntu). List with -K option.
	SETTINGS[deps_fed]="ImageMagick dcraw ffmpeg python3 python-pip perl-Image-ExifTool glibc-devel.i686" #Dependency package names (Fedora). List with -K option.
	SETTINGS[deps_brew]="imagemagick dcraw ffmpeg python3 exiftool"
	
	SETTINGS[deps_pip]="numpy tifffile" #You dont need Pillow. Thats just to make balance.py a bit more portable.
	SETTINGS[deps_man]="mlv_dump raw2dng cr2hdr mlv2badpixels.sh balance.py sRange.py color-core"
	
	if [[ $OSTYPE == "linux-gnu" ]]; then
		SETTINGS[path_python]="python3"
	elif [[ $OSTYPE == "darwin11" ]]; then
		SETTINGS[path_python]="python3"
	else
		SETTINGS[path_python]="python"
	fi


#PATHS
	SCRIPT_LOCATION=$(dirname "$(readlinkF "$0")")
	SRC_PATH="$SCRIPT_LOCATION/src" #Source components will always be looked for here.
	BIN_PATH="./binaries"
	GCONFIG="${HOME}/convmlv.conf"
	LCONFIG="" #No local config by default.

	setPaths #Set all the paths using the current SRC_PATH and BIN_PATH.

	OUTDIR="./raw_conv"
	isOutGen=false
	
	#new array method
	SETTINGS[path_script]=$(dirname "$(readlinkF "$0")")
	SETTINGS[path_src]="$SCRIPT_LOCATION/src" #Source components will always be looked for here.
	SETTINGS[path_bin]="./binaries"
	
	SETTINGS[path_config_global]="${HOME}/convmlv.conf"
	SETTINGS[path_config_local]="" #No local config by default.

	setPaths #Set all the paths using the current SRC_PATH and BIN_PATH.

	SETTINGS[path_output]="./raw_conv"

#OUTPUT
	MOVIE=false
	RES_IN=""
	FPS=24 #Will be read from .MLV or .RAW.
	IMAGES=false
	IMG_FMT="exr"
	COMPRESS=""
	isCOMPRESS=true
	isJPG=false
	isH264=false
	KEEP_DNGS=false
	
	#new array method
	SETTINGS[develop_movie]=false
	SETTINGS[develop_images]=false
	RES_IN=""
	SETTINGS[raw_fps]=24 #Will be read from .MLV or .RAW.
	SETTINGS[img_format]="exr"
	SETTINGS[img_compress]=true
	SETTINGS[proxy_jpg]=false
	SETTINGS[proxy_h264]=false
	SETTINGS[proxy_scale]="50%"
	SETTINGS[develop_keep-raw]=false
	#~ COMPRESS=""

#FRAME RANGE
	FRAME_RANGE="" #UPDATED LATER WHEN FRAME # IS AVAILABLE.
	FRAME_START="1"
	FRAME_END=""
	RANGE_BASE=""
	isFR=true
	
	#new array method
	SETTINGS[frame_range]="" #UPDATED LATER WHEN FRAME # IS AVAILABLE.
	SETTINGS[frame_start]="1"
	SETTINGS[frame_end]=""
	#~ RANGE_BASE="" #Where the raw argument frame range is spit into.
	#~ isFR=true #True when frame range needn't be touched.

#RAW DEVELOPOMENT
	HIGHLIGHT_MODE="0"
	PROXY_SCALE="50%"
	DEMO_MODE="1"
	DEPTH="-W -6"
	DEPTH_OUT="-depth 16"
	WAVE_NOISE=""
	FOUR_COLOR=""
	CHROMA_SMOOTH="--no-cs"
	
	#new array method
	SETTINGS[dev_blacklevel]="2048" #MODE DETERMINE AFTER PARSE
	SETTINGS[dev_satpoint]="standard" #MODE DETERMINE AFTER PARSE
	#Options: standard, <any num>
	SETTINGS[dcraw_satpoint]=""
	
	SETTINGS[dcraw_high-mode]="0"
	SETTINGS[dev_demosaic]="ppg" #MODE DETERMINE AFTER PARSE.
	#OPTIONS: bilin, vng, ppg, ahd.
	SETTINGS[dcraw_demosaic]="2"
	
	SETTINGS[dev_csmooth]="none" #MODE DETERMINE AFTER PARSE.
	#OPTIONS: none, 2x2, 3x3, 5x5
	SETTINGS[dcraw_csmooth]="--no-cs"
	SETTINGS[cr2hdr_csmooth]="--no-cs"
	SETTINGS[mlvfs_csmooth]=""
	
	SETTINGS[dev_depth]="16" #MODE DETERMINE AFTER PARSE.
	SETTINGS[dcraw_depth]="-W -6"
	SETTINGS[im_depth]="-depth 16"

	SETTINGS[nr_wave]=""
	SETTINGS[dcraw_four-color]=""
		
#COLOR MANAGEMENT
	GAMMA="1 1" #As far as dcraw is concerned, output is linear.
	SPACE="5" #dcraw only outputs Linear XYZ. LUTs convert onwards.
	COLOR_GAMMA="lin" #STANDARD marks it such that it will correspond to the gamut
	COLOR_GAMUT="srgb"
	COLOR_VF="" #Standard (~2.4) sRGB LUT by default: ${CORE_LUT}/lin_xyz--srgb_srgb.cube . This is used in VF_FILTERS
	colorDesc=""
	
	#new array method
	SETTINGS[col_gamma]="lin"
	SETTINGS[dcraw_gamma]="1 1"
	
	SETTINGS[col_gamut]="srgb"
	SETTINGS[dcraw_space]="5"
	
	#Again, the dcraw-specific stuff is assembled down the line.
	#~ GAMMA="1 1" #As far as dcraw is concerned, output is linear.
	#~ SPACE="5" #dcraw only outputs Linear XYZ. LUTs convert onwards.
	#~ COLOR_GAMMA="lin" #STANDARD marks it such that it will correspond to the gamut
	#~ COLOR_GAMUT="srgb"
	#~ COLOR_VF="" #Standard (~2.4) sRGB LUT by default: ${CORE_LUT}/lin_xyz--srgb_srgb.cube . This is used in VF_FILTERS
	#~ colorDesc=""

#FEATURES
	DUAL_ISO=false
	BADPIXELS=""
	BADPIXEL_PATH=""
	isBP=false
	DARKFRAME=""
	useDF=false
	DARK_PROC=""
	RES_DARK=""
	DARK_OUT=""
	BLACK_LEVEL=""
	
	#new array method
	SETTINGS[dev_diso]=false
	
	SETTINGS[dev_badpixel]=false #MODE DETERMINE AFTER PARSE
	SETTINGS[path_badpixel-cust]=""
	SETTINGS[dcraw_badpixel]=""
	
	SETTINGS[cali_bias_num]=-1 #0 to index, -1 denotes not used.
	SETTINGS[cali_dark_num]=-1 #0 to index, -1 denotes not used.
	SETTINGS[cali_flat_num]=-1 #0 to index, -1 denotes not used.
	
	SETTINGS[cali_bias_path]=""
	SETTINGS[cali_dark_path]=""
	SETTINGS[cali_flat_path]=""
	
	SETTINGS[cali_out_path]="" #The filename (sans extension) finished calibration frames are spit out to.
	
	#~ DARK_PROC="" #Variable where dcraw darkframe snipper can be found.

#White Balance
	WHITE=""
	GEN_WHITE=false
	CAMERA_WB=true
	WHITE_SPD=15
	isScale=false
	SATPOINT=""

	WHITE=""
	GEN_WHITE=false
	CAMERA_WB=true
	WHITE_SPD=15
	isScale=false

#FFMPEG Filters
	FFMPEG_FILTERS=false #Whether or not FFMPEG filters are going to be used.
	V_FILTERS=""
	V_FILTERS_PROX=""
	FILTER_ARR=()
	TEMP_NOISE="" #Temporal noise reduction.
	tempDesc=""
	LUTS=() #lut3d LUT application. Supports multiple LUTs, in a chain; therefore it is an array.
	lutDesc=""
	DESHAKE="" #deshake video stabilisation.
	deshakeDesc=""
	HQ_NOISE="" #hqdn3d noise reduction.
	hqDesc=""
	REM_NOISE="" #removegrain noise reduction
	remDesc=""
	SHARP=""
	sharpDesc=""
	
	#new array method
	SETTINGS[ffilters]=false #Whether or not FFMPEG filters are going to be used.
	#~ V_FILTERS=""
	#~ V_FILTERS_PROX=""
	#~ FILTER_ARR=()
	SETTINGS[ffilters_temp-noise]=""
	#~ TEMP_NOISE="" #Temporal noise reduction.
	#~ tempDesc=""
	SETTINGS[ffilters_luts]="()"
	#~ LUTS=() #lut3d LUT application. Supports multiple LUTs, in a chain; therefore it is an array.
	#~ lutDesc=""
	SETTINGS[ffilters_deshake]=""
	#~ DESHAKE="" #deshake video stabilisation.
	#~ deshakeDesc=""
	SETTINGS[ffilters_hqnoise]=""
	#~ HQ_NOISE="" #hqdn3d noise reduction.
	#~ hqDesc=""
	SETTINGS[ffilters_remnoise]=""
	#~ REM_NOISE="" #removegrain noise reduction
	#~ remDesc=""
	SETTINGS[ffilters_sharp]=""
	#~ SHARP=""
	#~ sharpDesc=""
	
	SETTINGS[raw_cam-name]="Unknown"
	SETTINGS[raw_frames]="Unknown"
	SETTINGS[raw_resolution]="Unknown"
	SETTINGS[raw_iso]="Unknown"
	SETTINGS[raw_aperture]="Unknown"
	SETTINGS[raw_flength]="Unknown"
	SETTINGS[raw_shutter]="Unknown"
	SETTINGS[raw_rec-time]="Unknown"
	SETTINGS[raw_rec-date]="Unknown"
	SETTINGS[raw_kelvin]="Unknown"
	
	baseSet() { #All camera attributes are reset here.
		CAM_NAME="Unknown"
		FRAMES="Unknown"
		RES_IN="Unknown"
		ISO="Unknown"
		APERTURE="Unknown"
		LEN_FOCAL="Unknown"
		SHUTTER="Unknown"
		REC_DATE="Unknown"
		REC_TIME="Unknown"
		KELVIN="Unknown"
	}
	
	baseSet
}

setDefaults #Run once now, and whenever you wish to reset things.

#DEFAULT PROGRAM - what it is we're actually doing right now.
PROGRAM="develop"
#Possible values:
#~ help: Display help page!
#~ version: Display version!
#~ darkframe: Create darkframe!
#~ settings: Show MLV settings!
#~ develop: What we do best!


#IMPORT MODULES GLOBALLY - into this namespace directly.
source "$SRC_PATH/documentation/help.sh"
source "$SRC_PATH/helpers/platform.sh"
source "$SRC_PATH/programs/shotSettings.sh"
source "$SRC_PATH/helpers/format.sh"
source "$SRC_PATH/programs/califrame.sh"
source "$SRC_PATH/helpers/utility.sh"
source "$SRC_PATH/core/parsing.sh"
source "$SRC_PATH/core/argFuncs.sh"
source "$SRC_PATH/helpers/error.sh"
source "$SRC_PATH/core/develop.sh"
source "$SRC_PATH/core/proc.sh"
source "$SRC_PATH/imgProcessing/imgMath.sh"


#OPTION PARSING FROM CONFIG AND CLI - same as at bottom of develop().

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


THREADS=$(getThreads)
ARGNUM=$#
FILE_ARGS="$@"
IFS=' ' read -r -a FILE_ARGS_ARRAY <<< $FILE_ARGS #Need to make arguments an array, for iteration over paths purposes.

#Choose which PROGRAM to run - from the multitude of things convmlv can do!
case "$PROGRAM" in
	help)
		help
		;;
	version)
		echo "$VERSION"
		;;
	darkframe)
		mkDarkframe
		;;
	settings)
		checkDeps #Check static dependencies.
		printFileSettings
		;;
	develop)
		checkDeps #Check static dependencies.
		
		ARG_INC=0
		for ARG in "${FILE_ARGS_ARRAY[@]}"; do #Go through FILE_ARGS_ARRAY array, copied from parsed $@ because $@ is going to be changing on 'set --'
		#Check the argument
			fReturn=$(checkArg "$ARG")
			if [[ $fReturn = "false" ]]; then continue; fi
			
		#Evaluate local configuration file for file-specific blocks.
			parseConf "$LCONFIG" true
			
		#Do the development step, using the globals that exist.
			develop "$ARG"
			
		#Experimental Assoc Array
			unset SETTINGS
			
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
			
		#Decrement the arguments that are left.
			let ARG_INC++
		done
		;;
esac

exit 0
