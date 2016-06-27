#!/bin/bash

#TODO:
#~ Stats for .RAW files.
#~ Integrate anti-vertical banding. May require being able to use multiple darkframe files.

#~ Better Preview:
#~ --> A different module (like -e) for live viewing of footage, under convmlv settings. Danne is working on this :).

#BUG: Relative OUTDIR makes baxpixel generation fail if ./mlv2badpixels.sh doesn't exist. Fixed on Linux only.
#CONCERN: Weirdness with color spaces in general. No impact to user; just some weirdly placed sRGB conversions if'ed by DPX.
#~ --> See Nasty Hacks Part 1 - 3. FML :O.
#~ I'll feel better about this after quite a while


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
VERSION="1.9.3" #Version string.
INPUT_ARGS=$(echo "$@") #The original input argument string.

if [[ $OSTYPE == "linux-gnu" ]]; then
	THREADS=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1)
else
	THREADS=4
fi
#sysctl -n hw.ncpu for Mac?

setPaths() { #Repends on RES_PATH and PYTHON. Run this function if either is changed.
	MLV_DUMP="${RES_PATH}/mlv_dump" #Path to mlv_dump location.
	RAW_DUMP="${RES_PATH}/raw2dng" #Path to raw2dng location.
	CR_HDR="${RES_PATH}/cr2hdr" #Path to cr2hdr location.
	MLV_BP="${RES_PATH}/mlv2badpixels.sh"
	PYTHON_BAL="${RES_PATH}/balance.py"
	PYTHON_SRANGE="${RES_PATH}/sRange.py"
	BAL="${PYTHON} ${PYTHON_BAL}"
	SRANGE="${PYTHON} ${PYTHON_SRANGE}"
}

setDefaults() { #Set all the default variables. Run here, and also after each ARG run.
#DEPENDENCIES
	DEB_DEPS="imagemagick dcraw ffmpeg python3 python3-pip exiftool" #Dependency package names (Debian). List with -K option.
	PIP_DEPS="numpy Pillow tifffile" #Technically, you don't need Pillow. I'm not really sure :).
	MAN_DEPS="mlv_dump raw2dng cr2hdr mlv2badpixels.sh balance.py sRange.py"
	if [[ $OSTYPE == "linux-gnu" ]]; then
		PYTHON="python3"
	else
		PYTHON="python"
	fi


#PATHS
	RES_PATH="." #Current Directory by default.
	GCONFIG="${HOME}/convmlv.conf"
	LCONFIG="" #No local config by default.

	setPaths #Set all the paths using the current RES_PATH.

	OUTDIR="./raw_conv"
	isOutGen=false

#OUTPUT
	MOVIE=false
	FPS=24 #Will be read from .MLV or .RAW.
	IMAGES=false
	IMG_FMT="exr"
	COMPRESS=""
	isCOMPRESS=true
	isJPG=false
	isH264=false
	KEEP_DNGS=false

#FRAME RANGE
	FRAME_RANGE="" #UPDATED LATER WHEN FRAME # IS AVAILABLE.
	FRAME_START="1"
	FRAME_END=""
	RANGE_BASE=""
	isFR=true

#RAW DEVELOPOMENT
	HIGHLIGHT_MODE="0"
	PROXY_SCALE="50%"
	DEMO_MODE="1"
	GAMMA="1 1"
	SPACE="0" #Color Space. Correlates to Gamma.
	DEPTH="-W -6"
	DEPTH_OUT="-depth 16"
	WAVE_NOISE="" #Used to be NOISE_REDUC. Wavelet noise reduction.
	FOUR_COLOR=""
	CHROMA_SMOOTH="--no-cs"

#FEATURES
	DUAL_ISO=false
	BADPIXELS=""
	BADPIXEL_PATH=""
	isBP=false
	DARKFRAME=""
	SETTINGS_OUTPUT=false
	MK_DARK=false
	DARK_OUT=""
	BLACK_LEVEL=""

#White Balance
	WHITE=""
	GEN_WHITE=false
	CAMERA_WB=true
	WHITE_SPD=15
	isScale=false
	SATPOINT=""

#FFMPEG Filters
	FFMPEG_FILTERS=false #Whether or not FFMPEG filters are going to be used.
	TEMP_NOISE="" #Temporal noise reduction.
	tempDesc=""
	LUT="" #lut3d LUT application
	lutDesc=""
	DESHAKE="" #deshake video stabilisation.
	deshakeDesc=""
	HQ_NOISE="" #hqdn3d noise reduction.
	hqDesc=""
	REM_NOISE="" #removegrain noise reduction
	remDesc=""
}

setDefaults #Run now, but also later.

help() {
less -R << EOF 
Usage:
	$(echo -e "\033[1m./convmlv.sh\033[0m [FLAGS] [OPTIONS] \033[2mfiles\033[0m")
	
INFO:
	A script allowing you to develop ML files into workable formats. Many useful options are exposed.
	  --> Image Defaults: Compressed 16-bit Linear EXR.
	  --> Acceptable Inputs: MLV, RAW, DNG Folder.
	  --> Option Input: From command line or config file.
	  
	  --> Forum Post: http://www.magiclantern.fm/forum/index.php?topic=16799.
	
$(echo -e "VERSION: ${VERSION}")
	
MANUAL DEPENDENCIES:
	-mlv_dump: Required. http://www.magiclantern.fm/forum/index.php?topic=7122.0
	-raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0
	-mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src
	-cr2hdr: For Dual ISO Development. Two links: http://www.magiclantern.fm/forum/index.php?topic=16799.0
	-sRange.py: Required. See convmlv repository.
	-balance.py: For Auto White Balance. See convmlv repository.

OPTIONS, BASIC:
	-v, --version		version - Print out version string.
	-h, --help		help - Print out this help page.
	
	-C, --config		config - Designates config file to use.
	
	-o, --outdir <path>	OUTDIR - The path in which files will be placed.
	-P, --res-path <path>	RES_PATH - The path in which all manual dependencies are looked for.
	
	--mlv-dump <path>	MLV_DUMP - The path to mlv_dump.
	--raw-dump <path>	RAW_DUMP - The path to raw2dng.
	--badpixels <path>	MLV_BP - The path to mlv2badpixels.sh (by dfort).
	--cr-hdr <path>		CR_HDR - The path to cr2hdr.
	--srange <path>	 	SRANGE - The path to sRange.py.
	--balance <path>	BAL - The path to balance.py.
	--python <path>		PYTHON - The path or command used to invoke Python.
	
	-T, --threads [int]	THREADS - Override amount of utilized process threads
	
	
OPTIONS, OUTPUT:
	-i			IMAGE - Will output image sequence.
	
	-t [0:3]		IMG_FMT - Specified image output format.
	  --> 0: EXR (default), 1: TIFF, 2: PNG, 3: Cineon (DPX)."
	  --> Note: Only EXR supports Linear output. Specify -g 3 if not using EXR.
	
	-m			MOVIE - Will output a Prores4444 file.
	
	-p [0:3]		PROXY - Create proxies alongside main output.
	  --> 0: No proxies (Default). 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.
	  --> JPG proxy *won't* be developed w/o IMAGE. H.264 proxy *will* be developed no matter what, if specified.
	
	-s [0%:100%]		PROXY_SCALE - the size, in %, of the proxy output.
	  --> 50% is default.
	
	-k			KEEP_DNGS - Specify if you want to keep the DNG files.
	  --> Run convmlv on the top level folder of former output to reuse saved DNGs from that run!
	  
	-r <start>-<end>	FRAME_RANGE - Specify to output this frame range only.
	  --> You may use s and e, such that s = start frame, e = end frame.
	  --> Indexed from 0 to (# of frames - 1).
	  --> A single number may be writted to develop that frame only.
	
	
	--uncompress		UNCOMP - Turns off lossless image compression. Otherwise:
	  --> TIFF: ZIP, EXR: PIZ, PNG: lvl 9 (zlib deflate), DPX: RLE.
	
	
OPTIONS, RAW DEVELOPMENT:
	-d [0:3]		DEMO_MODE - Demosaicing algorithm. Higher modes are slower + better.
	  --> 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.
	
	-f	FOUR_COLOR - Interpolate as RGBG. Can often fix weirdness with VNG/AHD.
	
	-H [0:9]		HIGHLIGHT_MODE - Highlight management options.
	  --> 0: White, clipped highlights. 1: Clipped, colored highlights. 2: Similar to 1, but adjusted to grey.
	  --> 3-9: Highlight reconstruction. Can cause flickering; 1 or 2 usually give better results.
	
	-c [0:3]		CHROMA_SMOOTH - Apply shadow/highlight chroma smoothing to the footage.
	  --> 0: None (default). 1: 2x2. 2: 3x3. 3: 5x5.
	  --> MLV Only.
	
	-n [int]		WAVE_NOISE - Apply wavelet denoising.
	  --> Default: None. Subtle: 25. Medium: 50. Strong: 125.
	  
	-N <A>-<B>		TEMP_NOISE - Apply temporal denoising.
	  --> A: 0 to 0.3. B: 0 to 5. A reacts to abrupt noise (splotches), B reacts to noise over time (fast motion causes artifacts).
	  --> Subtle: 0.03-0.04. High: 0.15-0.04. High, Predictable Motion: 0.15-0.07
	  
	-Q [i-i:i-i]		HQ_NOISE - Apply 3D denoising filter.
	  --> In depth explanation: https://mattgadient.com/2013/06/29/in-depth-look-at-de-noising-in-handbrake-with-imagevideo-examples/ .
	  --> Spacial/Temporal (S/T). S will soften/blur/smooth, T will remove noise without doing that but may create artifacts.
	  --> Luma/Chroma (L/C). L is the detail, C is the color. Each one's denoising may be manipulated Spacially or Temporally.
	  
	  --> Option Value: <LS>-<CS>:<LT>-<CT>
	  --> Weak: 2-1:2-3. Medium: 3-2:2-3. Strong: 7-7:5-5
	
	-G [i-i-i-i]		REM_NOISE - Yet another spatial denoiser, with 4 choices of 24 modes.
	  --> See https://ffmpeg.org/ffmpeg-filters.html#removegrain for list of modes.
	  
	  --> Option Value: <mode1>-<mode2>-<mode3>-<mode4>
	  --> I truly cannot tell you what values will be helpful to you; there are too many... Look at the link above!
	
	-g [0:4]		SPACE - Output color transformation.
	  --> 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.
	
	--shallow 		SHALLOW - Output 8-bit files.
	
	
OPTIONS, COLOR:
	-w [0:2]		WHITE - This is a modal white balance setting.
	  --> 0: Auto WB. 1: Camera WB (default). 2: No Change.
	  
	-l <path>		LUT - Specify a LUT to apply.
	  --> Supports cube, 3dl, dat, m3d.
	  
	-S [int]		SATPOINT - Specify the 14-bit saturation point of your camera. You don't usually want to.
	  --> Lower if -H1 yields purple highlights. Must be correct for highlight reconstruction.
	  --> Determine using the max value of 'dcraw -D -j -4 -T'
	
	--white-speed [int]	WHITE_SPD - Samples used to calculate AWB
	
	--allow-white-clip	WHITE_CLIP - Let White Balance multipliers clip.
	
	
OPTIONS, FEATURES:
	-D			DESHAKE - Stabilize the video using the wonderful ffmpeg "deshake" module.
	--> You'll probably wish to crop/scale the output in editing, to avoid edge artifacts.
	
	-u			DUAL_ISO - Process as dual ISO.
	
	-b			BADPIXELS - Fix focus pixels issue using dfort's script.
	
	-a <path>		BADPIXEL_PATH - Use your own .badpixels file.
	  --> How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686
	
	-F <path>		DARKFRAME - This is the path to a "dark frame MLV"; effective for noise reduction.
	  --> How to: Record 5 sec w/lens cap on & same settings as footage. Pass MLV in here.
	  --> If the file extension is '.darkframe', the file will be used as the preaveraged dark frame.
	
	-R <path>		dark_out - Specify to create a .darkframe file from passed in MLV.
	 --> Usage: 'convmlv -R <path> <input>.MLV'
	 --> Averages <input>.MLV to create <path>.darkframe.
	 --> THE .darkframe EXTENSION IS ADDED FOR YOU.
	
	
OPTIONS, INFO:
	-q			Output MLV settings.
	
	-K			Debian Package Deps - Output package dependecies.
	  --> Install (Debian only): sudo apt-get install $ (./convmlv -K)
	
	-Y			Python Deps - Lists Python dependencies. Works directly with pip.
	  -->Install (Linux): sudo pip3 install $ (./convmlv -Y)
	
	-M			Manual Deps - Lists manual dependencies, which must be downloaded by hand.
	  --> There's no automatic way to install these. See http://www.magiclantern.fm/forum/index.php?topic=16799.0 .
	
CONFIG FILE:
	Config files, another way to specify options, can save you time & lend you convenience in production situations.
	
	$(echo -e "\e[1mGLOBAL\e[0m"): $HOME/convmlv.conf
	$(echo -e "\e[1mLOCAL\e[0m"): Specify -C/--config.
	
	
	$(echo -e "\e[1mSYNTAX:\e[0m")
		Most options listed above have an uppercased VARNAME, ex. OUTDIR. Yu can specify such options in config files, as such:
		
			<VARNAME> <VALUE>
			
		One option per line only. Indentation by tabs or spaces is allowed, but not enforced.
			
		$(echo -e "\e[1mComments\e[0m") Lines starting with # are comments.
		
		You may name a config using:
		
			CONFIG_NAME <name>
			
		$(echo -e "\e[1mFlags\e[0m") If the value is a true/false flag (ex. IMAGE), simply specifying VARNAME is enough. THere is no VALUE.
	
	$(echo -e "\e[1mOPTION ORDER OF PRECEDENCE\e[0m") Options override each other as such:
		-LOCAL options overwrite GLOBAL options.
		-COMMAND LINE options overwrite LOCAL & GLOBAL options.
		-FILE SPECIFIC options overwrite ALL ABOVE options.
	
	
	$(echo -e "\e[1mFile-Specific Block\e[0m"): A LOCAL config file lets you specify options for specific input names:
	
		/ <TRUNCATED INPUTNAME>
			...options here will only be 
		*
		
		You must use the truncated (no .mlv or .raw) input name after the /. Nested blocks will fail.
		
		With a single config file, you can control the development options of multiple inputs as specifically and/or generically
		as you want. Batch developing everything can then be done with a single, powerful commmand.
		


Contact me with any feedback or questions at convmlv@sofusrose.com, or PM me (so-rose) on the ML forums!
EOF
}

mkdirS() {
	path=$1
	cleanup=$2
	cont=false
		
	if [ -d $path ]; then
		while true; do
			read -p "Overwrite ${path}? [y/n/q] " ynq
			case $ynq in
				[Yy]* ) echo -e ""; rm -rf $path; mkdir -p $path >/dev/null 2>/dev/null; break
				;;
				[Nn]* ) echo -e "\n\e[0;31m\e[1mDirectory ${path} won't be created.\e[0m\n"; cont=true; `$cleanup`; break
				;;
				[Qq]* ) echo -e "\n\e[0;31m\e[1mHalting execution. Directory ${path} won't be created.\e[0m\n"; exit 1;
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

evalConf() {
	file=$1 #The File to Parse
	argOnly=$2 #If true, will only use file-specific blocks. If false, will ignore file-specific blocks.
	CONFIG_NAME="None"
	
	if [[ -z $file ]]; then return; fi
	
	fBlock=false #Whether or not we are in a file-specific block.
	
	while IFS="" read -r line || [[ -n "$line" ]]; do
		line=$(echo "$line" | sed -e 's/^[ \t]*//') #Strip leading tabs/whitespaces.
		
		if [[ `echo "${line}" | cut -c1-1` == "#" ]]; then continue; fi #Ignore comments
		
		if [[ `echo "${line}" | cut -c1-1` == "/" && `echo "${line}" | cut -d$' ' -f2` == $TRUNC_ARG ]]; then
			if [[ $fBlock == true ]]; then echo "\n\e[0;31m\e[1mWARNING: Nested blocks!!!\e[0m"; fi
			fBlock=true
		fi #Enter a file-specific block with /, provided the argument name is correct.
		
		if [[ `echo "${line}" | cut -c1-1` == "*" ]]; then fBlock=false; fi #Leave a file-specific block.
			
		if [[ ($argOnly == false && $fBlock == false) || ($argOnly == true && $fBlock == true) ]]; then #Conditions under which to write values.
			case `echo "${line}" | cut -d$' ' -f1` in
				"CONFIG_NAME") CONFIG_NAME=`echo "${line}" | cut -d$' ' -f2` #Not doing anything with this right now.
				;;
				"OUTDIR") OUTDIR=`echo "${line}" | cut -d$' ' -f2`
				;;
				"RES_PATH") RES_PATH=`echo "${line}" | cut -d$' ' -f2`; setPaths
				;;
				"MLV_DUMP") MLV_DUMP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"RAW_DUMP") RAW_DUMP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"MLV_BP") MLV_BP=`echo "${line}" | cut -d$' ' -f2`
				;;
				"SRANGE") CR_HDR=`echo "${line}" | cut -d$' ' -f2`
				;;
				"BAL") PYTHON_SRANGE=`echo "${line}" | cut -d$' ' -f2`; setPaths
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
					esac
				;;
				"PROXY_SCALE") PROXY_SCALE=`echo "${line}" | cut -d$' ' -f2`
				;;
				"KEEP_DNGS") KEEP_DNGS=true
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
				"SPACE") 
					mode=`echo "${line}" | cut -d$' ' -f2`
					case ${mode} in
						"0")
							GAMMA="1 1"
							#~ SPACE="0" #What's going on here?
						;;
						"1")
							GAMMA="2.2 0"
							#~ SPACE="2"
						;;
						"2")
							GAMMA="1.8 0"
							#~ SPACE="4"
						;;
						"3")
							GAMMA="2.4 12.9"
							#~ SPACE="1"
						;;
						"4")
							GAMMA="2.222 4.5"
							#~ SPACE="0"
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
					esac
				;;
				"LUT")
					LUT_PATH=`echo "${line}" | cut -d$' ' -f2`
					
					if [ ! -f $LUT_PATH ]; then
						echo "LUT not found!!!"
						echo $LUT_PATH
						exit 1
					fi
					
					LUT="lut3d=${LUT_PATH}"
					lutDesc="3D LUT"
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
				"DARKFRAME") DARKFRAME=`echo "${line}" | cut -d$' ' -f2`
				;;
			esac
		fi
	done < "$1"
}

parseArgs() { #Amazing new argument parsing!!!
	longArg() { #Creates VAL
		ret="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
	}
	while getopts "vh C: o:P: T:  i t: m p: s: k r:  d: f H: c: n: N: Q: G: g:  w: l: S:  D u b a: F: R:  q K Y M    -:" opt; do
		#~ echo $opt ${OPTARG}
		case "$opt" in
			-) #Long Arguments
				case ${OPTARG} in
					outdir)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						OUTDIR=$val
						;;
					version)
						echo -e "convmlv v${VERSION}"
						;;
					help)
						help
						exit 0
						;;
					config)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						LCONFIG=$val
						;;
					res-path)
						val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
						RES_PATH=$val
						setPaths #Set all the paths with the new RES_PATH.
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
						echo "Invalid option: -$OPTARG" >&2
						;;
				esac
				;;
			
			
			v)
				echo -e "convmlv v${VERSION}"
				;;
			h)
				help
				exit 0
				;;
			C)
				LCONFIG=${OPTARG}
				;;
			o)
				OUTDIR=${OPTARG}
				;;
			P)
				RES_PATH=${OPTARG}
				setPaths #Set all the paths with the new RES_PATH.
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
				esac
				;;
			s)
				PROXY_SCALE=${OPTARG}
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
			G)
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
						GAMMA="1 1"
						#~ SPACE="0" #What's going on here?
					;;
					"1")
						GAMMA="2.2 0"
						#~ SPACE="2"
					;;
					"2")
						GAMMA="1.8 0"
						#~ SPACE="4"
					;;
					"3")
						GAMMA="2.4 12.9"
						#~ SPACE="1"
					;;
					"4")
						GAMMA="2.222 4.5"
						#~ SPACE="0"
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
				esac
				;;
			l)
				LUT_PATH=${OPTARG}
				if [ ! -f $LUT_PATH ]; then
					echo "LUT not found!!!"
					echo $LUT_PATH
					exit 1
				fi
				LUT="lut3d=${LUT_PATH}"
				lutDesc="3D LUT"
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
				;;
			F)
				DARKFRAME=${OPTARG}
				;;
			R)
				MK_DARK=true
				DARK_OUT=${OPTARG}
				;;
			
			
			q)
				SETTINGS_OUTPUT=true
				;;
			K)
				echo $DEB_DEPS
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

checkDeps() {
		argBase="$(basename "$ARG")"
		argExt="${argBase##*.}"
		argTrunc="${argBase%.*}"
		
		#Argument Checks
		if [ ! -f $ARG ] && [ ! -d $ARG ]; then
			echo -e "\e[0;31m\e[1mFile ${ARG} not found! Skipping file.\e[0m\n"
			let ARGNUM--; continue
		fi
		
		if [[ ! -d $ARG && ! ( $argExt == "MLV" || $argExt == "mlv" || $argExt == "RAW" || $argExt == "raw" ) ]]; then
			echo -e "\e[0;31m\e[1mFile ${ARG} has invalid extension!\e[0m\n"
			let ARGNUM--; continue
		fi
		
		if [[ ( ( ! -f $ARG ) && $(ls -1 ${ARG%/}/*.[Dd][Nn][Gg] 2>/dev/null | wc -l) == 0 ) && ( `folderName ${ARG}` != $argTrunc ) ]]; then
			echo -e "\e[0;31m\e[1mFolder ${ARG} contains no DNG files!\e[0m\n"
			let ARGNUM--; continue
		fi
		
		if [ ! -d $ARG ] && [ $(echo $(wc -c ${ARG} | cut -d " " -f1) / 1000 | bc) -lt 1000 ]; then #Check that the file is not too small.
			cont=false
			while true; do
				read -p "${ARG} is unusually small at $(echo "$(echo "$(wc -c ${ARG})" | cut -d$' ' -f1) / 1000" | bc)KB. Continue, skip, or remove? [c/s/r] " csr
				case $csr in
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
				let ARGNUM--; continue
			fi
		fi
		
		#Essentials
		if [ ! -f $MLV_DUMP ]; then
			echo -e "\e[0;31m\e[1m${MLV_DUMP} not found! Execution will halt.\e[0m\\n\tGet it here: http://www.magiclantern.fm/forum/index.php?topic=7122.0.\n"
			isExit=true
		fi
		
		if [ ! -f $PYTHON_SRANGE ]; then
			echo -e "\e[0;31m\e[1m${PYTHON_SRANGE} not found! Execution will halt.\e[0m\\n\tDownload from convmlv repository.\n"
			isExit=true
		fi
		
		if [ ! -f $DARKFRAME ] && [ $DARKFRAME != "" ]; then
			echo -e "\e[0;31m\e[1mDarkframe ${DARKFRAME} not found!\e[0m\n"
			isExit=true
		fi
		
		
		#Features
		if [ ! -f $PYTHON_BAL ]; then
			echo -e "\e[0;31m\e[1m${PYTHON_BAL} not found! Execution will continue without AWB.\e[0m\n\tDownload from convmlv repository.\n"
		fi
		
		if [ ! -f $RAW_DUMP ]; then
			echo -e "\e[0;31m\e[1m${RAW_DUMP} not found! Execution will continue without .RAW processing capability.\e[0m\\n\tGet it here: http://www.magiclantern.fm/forum/index.php?topic=5404.0\n"
		fi
		
		if [ ! -f $MLV_BP ]; then
			echo -e "\e[0;31m\e[1m${MLV_BP} not found! Execution will continue without badpixel removal capability.\e[0m\n\tGet it here: https://bitbucket.org/daniel_fort/ml-focus-pixels/src\n"
		fi
		
		if [ ! -f $CR_HDR ]; then
			echo -e "\e[0;31m\e[1m${CR_HDR} not found! Execution will continue without Dual ISO processing capability.\e[0m\n\tGet it here: http://www.magiclantern.fm/forum/index.php?topic=7139.0\n"
		fi
		
		
		if [[ $isExit == true ]]; then
			echo -e "\e[0;33m\e[1mPlace all downloaded files in the Current Directory, or specify paths with relevant arguments (see 'convmlv -h')! Also, make sure they're executable (run 'chmod +x file').\e[0m\n"
			exit 1
		fi
}

bold() {
	echo -e "\e[1m${1}\e[0m"
}

folderName() {
	#Like basename, but for folders.
	echo "$1" | rev | cut -d$'/' -f1 | rev
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
	camDump=$(${MLV_DUMP} -v -m ${ARG}) #Read it in *once*; otherwise it's unbearably slow on external media.
	
	FPS=`echo "$camDump" | grep FPS | awk 'FNR == 1 {print $3}'`
			
	CAM_NAME=`echo "$camDump" | grep 'Camera Name' | cut -d "'" -f 2`
	FRAMES=`echo "$camDump" | awk '/Processed/ { print $2; }'` #Use actual processed frames as opposed to what the sometimes incorrect metadata thinks.
	ISO=`echo "$camDump" | grep 'ISO' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f2`
	APERTURE=`echo "$camDump" | grep 'Aperture' | sed 's/[[:alpha:] ]*:    //' | cut -d$'\n' -f1`
	LEN_FOCAL=`echo "$camDump" | grep 'Focal Len' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
	SHUTTER=`echo "$camDump" | grep 'Shutter' | sed 's/[[:alpha:] ]*:   //' | grep -oP '\(\K[^)]+' |  cut -d$'\n' -f1`
	REC_DATE=`echo "$camDump" | grep 'Date' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	REC_TIME=`echo "$camDump" | grep 'Time:        [0-2][0-9]\:*' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	KELVIN=`echo "$camDump" | grep 'Kelvin' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
}

rawSet() { #To be implemented maybe - exiftool? Or raw_dump?
	CAM_NAME="Unknown"
	FRAMES="Unknown"
	ISO="Unknown"
	APERTURE="Unknown"
	LEN_FOCAL="Unknown"
	SHUTTER="Unknown"
	REC_DATE="Unknown"
	REC_TIME="Unknown"
	KELVIN="Unknown"
}

dngSet() { #Set as many options as the RAW spec will allow. Grey out the rest.
	for dng in $ARG/*.dng; do
		dataDNG=$dng
	done
	
	FPS=24 #Standard FPS.
	
	CAM_NAME=$(exiftool -UniqueCameraModel -s -s -s $dataDNG)
	ISO=$(exiftool -UniqueCameraModel -s -s -s $dataDNG)
	APERTURE=$(exiftool -ApertureValue -s -s -s $dataDNG)
	LEN_FOCAL=$(exiftool -FocalLength -s -s -s $dataDNG)
	SHUTTER=$(exiftool -ShutterSpeed -s -s -s $dataDNG)
	REC_DATE=$(echo "$(exiftool -DateTimeOriginal -s -s -s $dataDNG)" | cut -d$' ' -f1)
	REC_TIME=$(echo "$(exiftool -DateTimeOriginal -s -s -s $dataDNG)" | cut -d$' ' -f2)
	KELVIN="Unknown"
}

if [ $# == 0 ]; then
	echo -e "\e[0;31m\e[1mNo arguments given.\e[0m\n\tType 'convmlv -h/--help' to see help page, or 'convmlv -v/--version' for current version string."
fi


#MANUAL SANDBOXING + OPTION SOURCES - Making sure global, local, command line options all override each other correctly.
evalConf "$GCONFIG" false #Parse global config file.

parseArgs "$@" #First, parse all cli args. We only need the -C flag, but that forces us to just parse everything.
shift $((OPTIND-1)) #Shift past all of the options to the file arguments.
OPTIND=1 #To reset argument parsing, we must set OPTIND to 1.

evalConf "$LCONFIG" false #Parse local config file.
set -- $INPUT_ARGS #Reset $@ for cli option reparsing.

parseArgs "$@" #Reparse cli to overwrite local config options.
shift $((OPTIND-1))
OPTIND=1



ARGNUM=$#
FILE_ARGS="$@"
IFS=' ' read -r -a FILE_ARGS_ITER <<< $FILE_ARGS #Need to make it an array, for iteration over paths purposes.

for ARG in "${FILE_ARGS_ITER[@]}"; do #Go through FILE_ARGS_ITER array, copied from parsed $@ because $@ is going to be changing on 'set --'
	ARG="$(pwd)/${ARG}"
	
	if [[ $OSTYPE == "linux-gnu" ]]; then
		ARG="$(readlink -f $ARG)"  >/dev/null 2>/dev/null #Relative ARG only fixed on Linux, as readlink only exists in UNIX. Mac variant?
	fi
	
#The Very Basics
	BASE="$(basename "$ARG")"
	EXT="${BASE##*.}"
	TRUNC_ARG="${BASE%.*}"
	SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor for halved video, *2 for 50%
	setBL=true
	
	joinArgs() { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }
	
	#Construct the FFMPEG filters.
	if [[ $FFMPEG_FILTERS == true ]]; then
		FINAL_SCALE="scale=trunc(iw/2)*${SCALE}:trunc(ih/2)*${SCALE}"
		V_FILTERS="-vf $(joinArgs , ${DESHAKE} ${TEMP_NOISE} ${HQ_NOISE} ${REM_NOISE} ${LUT})"
		V_FILTERS_PROX="-vf $(joinArgs , ${DESHAKE} ${TEMP_NOISE} ${HQ_NOISE} ${REM_NOISE} ${LUT} ${FINAL_SCALE})" #Proxy filter set adds the scale component.
		
		#Created formatted array of filters, FILTER_ARR.
		declare -a compFilters=("${tempDesc}" "${lutDesc}" "${deshakeDesc}" "${hqDesc}" "${remDesc}")
		for v in "${compFilters[@]}"; do if test "$v"; then FILTER_ARR+=("$v"); fi; done
	fi
#Evaluate convmlv.conf configuration file for file-specific blocks.
	evalConf "$LCONFIG" true
#Check that things exist.
	checkDeps

#Potentially Print Settings
	if [ $SETTINGS_OUTPUT == true ]; then
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			# Read the header for interesting settings :) .
			mlvSet
			
			echo -e "\n\e[1m\e[0;32m\e[1mFile\e[0m\e[0m: ${ARG}\n"
			prntSet
			continue
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			rawSet
			
			echo -e "\n\e[1m\e[0;32m\e[1mFile\e[0m\e[0m: ${ARG}\n"
			prntSet
			continue
		elif [ -d $ARG ]; then
			dngSet
			
			echo -e "\n\e[1m\e[0;32m\e[1mFile\e[0m\e[0m: ${ARG}\n"
			prntSet
			continue
		else
			echo -e "Cannot print settings from ${ARG}; it's not an MLV file!"
			continue
		fi
	fi
	
	if [[ $MK_DARK == true ]]; then 
		echo -e "\n\e[1m\e[0;32m\e[1mAveraging Darkframe File\e[0m: ${ARG}"
		$MLV_DUMP -o $DARK_OUT $ARG 2>/dev/null 1>/dev/null
		echo -e "\n\e[1m\e[1mWrote Darkframe File\e[0m: ${DARK_OUT}\n"
		continue
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
	if [[ $OSTYPE == "linux-gnu" ]]; then
		OUTDIR="$(readlink -f $OUTDIR)"  >/dev/null 2>/dev/null #Relative Badpixel OUTDIR only fixed on Linux, as readlink only exists in UNIX. Mac variant?
	fi
	
	if [ $OUTDIR != $PWD ] && [ isOutGen == false ]; then
		mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP.
		isOutGen=true
	fi
	
	FILE="${OUTDIR}/${TRUNC_ARG}"
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	
	setRange() {
		#FRAMES must be set at this point.
		if [[ $isFR == true ]]; then #Ensure that FRAME_RANGE is set.
			FRAME_RANGE="1-${FRAMES}"
			FRAME_START="1"
			FRAME_END=$FRAMES
		else
			base=$(echo $RANGE_BASE | sed -e 's:s:0:g' | sed -e "s:e:$(echo "$FRAMES - 1" | bc):g") #FRAMES is incremented in a moment.
			
			#~ FRAME_RANGE_ZERO="$(echo $base | cut -d"-" -f1)-$(echo $base | cut -d"-" -f2)" #Number from 0. Useless as of now.
			FRAME_RANGE="$(echo "$(echo $base | cut -d"-" -f1) + 1" | bc)-$(echo "$(echo $base | cut -d"-" -f2) + 1" | bc)" #Number from 1.
			FRAME_START=$(echo ${FRAME_RANGE} | cut -d"-" -f1)
			FRAME_END=$(echo ${FRAME_RANGE} | cut -d"-" -f2)
		fi
	}
	
#DNG argument, reused or not. Also, create FILE and TMP.
	DEVELOP=true
	if [[ ( -d $ARG ) && ( ( `basename ${ARG} | cut -c1-3` == "dng" && -f "${ARG}/../settings.txt" ) || ( `basename ${ARG}` == $TRUNC_ARG && -f "${ARG}/settings.txt" ) ) ]]; then #If we're reusing a dng sequence, copy over before we delete the original.
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Moving DNGs from previous run...\n" #Use prespecified DNG sequence.
		
		#User may specify either the dng_ or the trunc_arg folder; must account for both.
		if [[ `folderName ${ARG}` == $TRUNC_ARG && -d "${ARG}/dng_${TRUNC_ARG}" ]]; then
			ARG="${ARG}/dng_${TRUNC_ARG}" #Set arg to the dng argument.
		elif [[ `folderName ${ARG}` == $TRUNC_ARG ]]; then
			echo -e "\e[0;31m\e[1mCannot reuse - DNG folder does not exist! Skipping argument.\e[0m"
			continue
		else
			TRUNC_ARG=`echo $TRUNC_ARG | cut -c5-${#TRUNC_ARG}`
		fi
		
		DNG_LOC=${OUTDIR}/tmp_reused
		mkdir -p ${OUTDIR}/tmp_reused
		
		find $ARG -iname "*.dng" | xargs -I {} mv {} $DNG_LOC #Copying DNGs to temporary location.
		
		FPS=`cat ${ARG}/../settings.txt | grep "FPS" | cut -d $" " -f2` #Grab FPS from previous run.
		FRAMES=`cat ${ARG}/../settings.txt | grep "Frames" | cut -d $" " -f2` #Grab FRAMES from previous run.
		cp "${ARG}/../settings.txt" $DNG_LOC
		
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
		
		setBL=false
		DEVELOP=false
		rm -r $DNG_LOC
	elif [ -d $ARG ]; then #If it's a DNG sequence, but not a reused one.
		mkdirS $FILE
		mkdirS $TMP
		
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Using specified folder of RAW sequences...\n" #Use prespecified DNG sequence.
		
		setRange
		
		i=0
		for dng in $ARG/*.dng; do
			cp $dng $(printf "${TMP}/${TRUNC_ARG}_%06d.dng" $i)
			let i++
			if [[ i -gt $FRAME_END ]]; then break; fi
		done
		
		FPS=24 #Set it to a safe default.
		FRAMES=$(find ${TMP} -name "*.dng" | wc -l)
		
		dngSet
		
		DEVELOP=false #We're not developing DNG's; we already have them!
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

#Develop sequence if needed.
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
		
		#IF extension is RAW, we want to convert to MLV. All the newer features are MLV-only, because of mlv_dump's amazingness.
		
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			# Read the header for interesting settings :) .
			mlvSet
			setRange
			
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

			devDNG() { #Takes n arguments: 1{}, the frame range 2$MLV_DUMP 3$REAL_MLV 4$DARK_PROC 5$tmpOut 6$smooth 7$TMP 8$FRAME_END 9$TRUNC_ARG 10$FRAME_START
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
						echo -e "\e[2K\rMLV to DNG: Frame $(echo "${cur} + ${10}" | bc)/${8}\c" #Print out beautiful progress bar, in parallel!
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
					bash -c "devDNG '{}' '$MLV_DUMP' '$REAL_MLV' '$DARK_PROC' '$tmpOut' '$smooth' '$TMP' '$FRAME_END' '$TRUNC_ARG' '$FRAME_START'"
			
			#Since devDNG must run in a subshell, globals don't follow. Must pass *everything* in.
			echo -e "\e[2K\rMLV to DNG: Frame ${FRAME_END}/${FRAME_END}\c" #Ensure it looks right at the end.
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
			echo -e $rawStat
			FPS=`$RAW_DUMP $ARG "${TMP}/${TRUNC_ARG}_" | awk '/FPS/ { print $3; }'` #Run the dump while awking for the FPS.
		fi
				
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng)
	fi
	
	BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng) #Use the first DNG to get the correct black level.
	
	prntSet > $FILE/settings.txt
	sed -i -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $FILE/settings.txt #Strip escape sequences.
	
	setRange #Just to be sure the frame range was set, in case the input isn't MLV.
	
#Create badpixels file.
	if [ $isBP == true ] && [ $DEVELOP == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating badpixels file...\n"
		
		bad_name="badpixels_${TRUNC_ARG}.txt"
		gen_bad="${TMP}/${bad_name}"
		touch $bad_name
		#~ exit
		
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
	fi

#Dual ISO Conversion
	if [ $DUAL_ISO == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Combining Dual ISO...\n"
		
		#Original DNGs will be moved here.
		oldFiles="${TMP}/orig_dng"
		mkdirS $oldFiles
		
		inc_iso() { #6 args: 1{} 2$CR_HDR 3$TMP 4$FRAME_END 5$oldFiles 6$CHROMA_SMOOTH. {} is a path. Progress is thread safe. Experiment gone right :).
			count=$(echo "$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) + 1" | bc) #Get count from filename.
			
			$2 $1 $6 >/dev/null 2>/dev/null #The LQ option, --mean23, is completely unusable in my opinion.
			
			name=$(basename "$1")
			mv "${3}/${name%.*}.dng" $5 #Move away original dngs.
			mv "${3}/${name%.*}.DNG" "${3}/${name%.*}.dng" #Rename *.DNG to *.dng.
			
			echo -e "\e[2K\rDual ISO Development: Frame ${count}/${4}\c"
		}
		
		export -f inc_iso #Must expose function to subprocess.
		
		find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | cut -d '' --complement -f $FRAME_RANGE | tr -d '\n' | xargs -0 -I {} -n 1 mv {} $oldFiles #Move all the others to correct position.
		find $TMP -maxdepth 1 -name "*.dng" -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 bash -c "inc_iso '{}' '$CR_HDR' '$TMP' '$FRAME_END' '$oldFiles' '$CHROMA_SMOOTH'"
				
		BLACK_LEVEL=$(exiftool -BlackLevel -s -s -s ${TMP}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).dng) #Use the first DNG to get the correct black level.

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
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Generating WB...\n"
		
		#Calculate n, the distance between samples.
		frameLen=$(echo "$FRAME_END - $FRAME_START" | bc)
		if [[ $WHITE_SPD -gt $frameLen ]]; then
			WHITE_SPD=$frameLen
		fi
		n=`echo "${frameLen} / ${WHITE_SPD}" | bc`
		
		toBal="${TMP}/toBal"
		mkdirS $toBal
		
		#Develop every nth file for averaging.
		i=0
		t=0
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do 
			if [ `echo "(${i}+1) % ${n}" | bc` -eq 0 ]; then
				dcraw -q 0 $BADPIXELS -r 1 1 1 1 -g $GAMMA -k $BLACK_LEVEL $SATPOINT -o $SPACE -T "${file}"
				name=$(basename "$file")
				mv "$TMP/${name%.*}.tiff" $toBal #TIFF MOVEMENT. We use TIFFs here because it's easy for dcraw and Python.
				let t++
			fi
			echo -e "\e[2K\rWB Development: Sample ${t}/$(echo "${frameLen} / $n" | bc) (Frame: $(echo "${i} + 1" | bc)/${FRAME_END})\c"
			let i++
		done
		echo ""
		
		#Calculate + store result into a form dcraw likes.
		echo -e "Calculating Auto White Balance..."
		BALANCE=`$BAL $toBal`
		
	elif [ $CAMERA_WB == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Retrieving Camera White Balance..."
		
		trap "rm -rf ${FILE}; exit 1" INT
		for file in $TMP/*.dng; do
			#dcraw a single file verbosely, to get the camera multiplier with awk.
			BALANCE=`dcraw -T -w -v -c ${file} 2>&1 | awk '/multipliers/ { print $2, $3, $4 }'`
			break
		done

	else #Something must always be set.
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Ignoring White Balance..."
		
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
	
	#Nasty Hack Part 1: Setting colorspace for dcrawImg must be done differently for non-exr formats to maintain linearity.
	if [[ $IMG_FMT == "exr"  || $IMG_FMT == "dpx" ]]; then
		NASTYHACK="RGB"
	else
		NASTYHACK="sRGB"
	fi
	#But even NASTYHACK is one Gamma 2.2 conversion above what it's supposed to be, even if the formats are now consistent.
	#So, this is useless...
		
	dcrawOpt() { #Find, develop, and splay raw DNG data as ppm, ready to be processed.
		find "${TMP}" -maxdepth 1 -iname "*.dng" -print0 | sort -z | tr -d "\n" | xargs -0 \
			dcraw -c -q $DEMO_MODE $FOUR_COLOR -k $BLACK_LEVEL $SATPOINT $BADPIXELS $WHITE -H $HIGHLIGHT_MODE -g $GAMMA $WAVE_NOISE -o $SPACE $DEPTH
	} #Is prepared to pipe all the files in TMP outwards.
	
	dcrawImg() { #Find and splay image sequence data as ppm, ready to be processed by ffmpeg.
		find "${SEQ}" -maxdepth 1 -iname "*.${IMG_FMT}" -print0 | sort -z | xargs -0 -I {} convert '{}' -colorspace ${NASTYHACK} ppm:-
	} #Finds all images, prints to stdout, without any operations, using convert. ppm conversion is inevitably slow, however...
	
	mov_main() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -vcodec prores_ks -n -r $FPS -profile:v 4444 -alpha_bits 0 -vendor ap4h $V_FILTERS $SOUND_ACTION "${VID}_hq.mov"
	} #-loglevel panic -stats
	
	mov_prox() {
		ffmpeg -f image2pipe -vcodec ppm -r $FPS -i pipe:0 \
			-loglevel panic -stats $SOUND -c:v libx264 -n -r $FPS -preset fast $V_FILTERS_PROX -crf 23 -c:a mp3 "${VID}_lq.mp4"
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
	
	img_par() { #Takes 20 arguments: {} 2$DEMO_MODE 3$FOUR_COLOR 4$BADPIXELS 5$WHITE 6$HIGHLIGHT_MODE 7$GAMMA 8$WAVE_NOISE 9$DEPTH 10$SEQ 11$TRUNC_ARG 12$IMG_FMT 13$FRAME_END 14$DEPTH_OUT 15$COMPRESS 16$isJPG 17$PROXY_SCALE 18$PROXY 19$BLACK_LEVEL 20$SPACE 21$SATPOINT
		count=$(echo $(echo $1 | rev | cut -d "_" -f 1 | rev | cut -d "." -f 1 | grep "[0-9]") | bc) #Instead of count from file, count from name!
		
		if [[ ${12} == "dpx" ]]; then NASTYHACK2="-colorspace sRGB"; else NASTYHACK2=""; fi #Nasty Hack, Part 2: IM applies an inverse sRGB curve on DPX, for some reason.
			#Trust me, I've tried everything else; but this seems to actually work, so. Bug fixed, I guess...
			
		if [ ${16} == true ]; then
			dcraw -c -q $2 $3 $4 $5 -H $6 -k ${19} ${21} -g $7 $8 -o ${20} $9 $1 | \
				tee >(convert ${14} - -set colorspace RGB ${15} $(printf "${10}/${11}_%06d.${12}" ${count})) | \
					convert - -set colorspace RGB -quality 80 -set colorspace sRGB -resize ${17} $(printf "${18}/${11}_%06d.jpg" ${count})
					#See below, in compression, formats for info on why I'm setting sRGB colorspace for a linear output...
			echo -e "\e[2K\rDNG to ${12^^}/JPG: Frame ${count^^}/${13}\c"
		else
			dcraw -c -q $2 $3 $4 $5 -H $6 -k ${19} ${21} -g $7 $8 -o ${20} $9 $1 | \
				convert ${14} - -set colorspace RGB ${NASTYHACK2} ${15} $(printf "${10}/${11}_%06d.${12}" ${count})
			echo -e "\e[2K\rDNG to ${12^^}: Frame ${count^^}/${13}\c"
		fi
	}
	
	#~ For XYZ->sRGB Input (Requires XYZ Identity ICC Profile):
	#~ convert ${14} -  +profile icm -profile "/home/sofus/subhome/src/convmlv/icc/XYZ-D50-Identity-elle-V4.icc" -set colorspace XYZ \
				#~ -color-matrix "3.2404542 -1.5371385 -0.4985314 \
                  #~ -0.9692660  1.8760108  0.0415560 \
                   #~ 0.0556434 -0.2040259  1.0572252" \
				#~ -set colorspace RGB ${15} $(printf "${10}/${11}_%06d.${12}" ${count})
		#~ See http://www.imagemagick.org/discourse-server/viewtopic.php?t=21161
	
	export -f img_par	
	
	
#PROCESSING

#IMAGE PROCESSING
	if [ $IMAGES == true ] ; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Processing Image Sequence from Frame ${FRAME_START} to ${FRAME_END}...\n"
		
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
		find "${TMP}" -maxdepth 1 -name '*.dng' -print0 | sort -z | xargs -0 -I {} -P $THREADS -n 1 \
			bash -c "img_par '{}' '$DEMO_MODE' '$FOUR_COLOR' '$BADPIXELS' '$WHITE' '$HIGHLIGHT_MODE' '$GAMMA' '$WAVE_NOISE' '$DEPTH' \
			'$SEQ' '$TRUNC_ARG' '$IMG_FMT' '$FRAME_END' '$DEPTH_OUT' '$COMPRESS' '$isJPG' '$PROXY_SCALE' '$PROXY' '$BLACK_LEVEL' '$SPACE' '$SATPOINT'"
		
		# Removed  | cut -d '' -f $FRAME_RANGE , as this happens when creating the DNGs in the first place.

		if [ $isJPG == true ]; then #Make it print "Frame $FRAMES / $FRAMES" as the last output :).
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}/JPG: Frame ${FRAME_END}/${FRAME_END}\c"
		else
			echo -e "\e[2K\rDNG to ${IMG_FMT^^}: Frame ${FRAME_END}/${FRAME_END}\c"
		fi
		
		echo -e "\n"
		
#FFMPEG Filter Application: Temporal Denoising, 3D LUTs, Deshake, hqdn Denoising, removegrain denoising so far. See construction of $V_FILTERS in PREPARATION.
		if [[ $FFMPEG_FILTERS == true ]]; then
			tmpFiltered=${TMP}/filtered
			mkdir $tmpFiltered
			
			#Give correct output.
			echo -e "\e[1mApplying Filters:\e[0m $(joinArgs ", " "${FILTER_ARR[@]}")...\n"
			
			if [ $IMG_FMT == "exr" ]; then
				echo -e "Note: EXRs may hang after filtering.\n"
				
				img_res=$(identify ${SEQ}/${TRUNC_ARG}_$(printf "%06d" $(echo "$FRAME_START" | bc)).${IMG_FMT} | cut -d$' ' -f3)
				
				convert "${SEQ}/${TRUNC_ARG}_%06d.exr[${FRAME_START}-${FRAME_END}]" -define stream:buffer-size=0 -set colorspace RGB  ppm:- | \
					ffmpeg -f image2pipe -vcodec ppm -s "${img_res}" -r $FPS -loglevel panic -stats -i pipe:0 \
					$V_FILTERS \
					-vcodec ppm -n -r $FPS -f image2pipe pipe:1 | \
						convert -depth 16 - -colorspace RGB -compress piz -set colorspace RGB "${tmpFiltered}/%06d.${IMG_FMT}"
						#For some reason, this whole process sends EXR's into sRGB. That's why -colorspace RGB is specified. See Nasty Hacks.
			else
				ffmpeg -start_number $FRAME_START -f image2 -i "${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT}" -loglevel panic -stats $V_FILTERS "${tmpFiltered}/%06d.${IMG_FMT}"
			fi
			echo ""
			
			#Replace the images in $SEQ with the filtered ones.
			i=$FRAME_START
			for img in $tmpFiltered/*.${IMG_FMT}; do
				repl=$(printf "${SEQ}/${TRUNC_ARG}_%06d.${IMG_FMT}" $i)
				
				mv $img $repl
				
				((i+=1))
			done
		fi
	fi
	
#MOVIE PROCESSING
	VID="${FILE}/${TRUNC_ARG}"
	
	SOUND="-i ${TMP}/${TRUNC_ARG}_.wav"
	SOUND_ACTION="-c:a mp3"
	if [ ! -f $SOUND_PATH ]; then
		SOUND=""
		SOUND_ACTION=""
	fi
	
	if [ $MOVIE == true ] && [ $IMAGES == false ]; then
		if [ $isH264 == true ]; then
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes/H.264..."
			runSim dcrawOpt mov_main mov_prox
		else
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			dcrawOpt | mov_main
		fi
		echo ""
	elif [ $MOVIE == true ] && [ $IMAGES == true ]; then #Use images if available, as opposed to developing the files again.
		V_FILTERS="" #We don't need this any more for this run - already applied to the images.
		V_FILTERS_PROX="-vf $FINAL_SCALE"
		if [ $isH264 == true ]; then
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes/H.264..."
			runSim dcrawOpt mov_main mov_prox #Used to run dcrawImg
		else
			echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to ProRes..."
			dcrawOpt | mov_main #Used to run dcrawImg
		fi
		echo ""
	fi
	
	if [ $MOVIE == false ] && [ $isH264 == true ]; then
		echo -e "\e[1m${TRUNC_ARG}:\e[0m Encoding to H.264..."
		if [ $IMAGES == true ]; then
			V_FILTERS_PROX="-vf $FINAL_SCALE" #See above note.
			dcrawOpt | mov_prox #Used to run dcrawImg
		else
			dcrawOpt | mov_prox
		fi
		echo ""
		#Nasty Hack Part 3: We can no longer use dcrawImg; colorspace conversions are a fucking circus.
		#Luckily, dcrawOpt isn't that much slower; even faster sometimes. Damn ppm conversion never pulled their weight.
	fi
	
#Potentially move DNGs.
	if [ $KEEP_DNGS == true ]; then
		echo -e "\e[1mMoving DNGs...\e[0m"
		DNG="${FILE}/dng_${TRUNC_ARG}"
		mkdirS $DNG
		
		if [ $DUAL_ISO == true ]; then
			oldFiles="${TMP}/orig_dng"
			find $oldFiles -name "*.dng" | xargs -I '{}' mv {} $DNG #Preserve the original, unprocessed DNGs.
		else
			find $TMP -name "*.dng" | xargs -I '{}' mv {} $DNG
		fi
	fi
	
	echo -e "\n\e[1mCleaning Up.\e[0m\n\n"
	
#Delete tmp
	rm -rf $TMP
	
#MANUAL SANDBOXING - see note at the header of the loop.
	setDefaults #Hard reset everything.
	
	evalConf "$GCONFIG" false #Rearse global config file.
	parseArgs "$@" #First, parse args all to set LCONFIG.
	shift $((OPTIND-1))
	OPTIND=1

	evalConf "$LCONFIG" false #Parse local config file.
	set -- $INPUT_ARGS #Reset the argument input for reparsing again, over the local config file.

	parseArgs "$@"
	shift $((OPTIND-1))
	OPTIND=1
	
	let ARGNUM--
done

exit 0
