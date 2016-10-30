#!/bin/bash

#TODO:

#PLANNING:
#	Except for openlut integration, CM fixes, and the last throes of Mac compatibility, I consider convmlv feature-complete. As in, only bug fixes and error checking.
#	New developments, like special ffmpeg filters, or new techniques from the ML world, may change that. But that's nothing compared to the 2400 lines this pushes at the moment!
#	Any further effort is better focused on compatibility, bug fixes, error checking, more bug fixes, and finally a GUI app described in FUTURE.


#~ TOP PRIORITY
#~ --> Fix Color Management; -o 5 is broken. Use -o 0, supplemented by current paradigm of Rec709 -> Whatever LUTs, instead of XYZ -> Whatever LUTs.

#~ HIGH PRIORITY
#~ --> Retest Darkframe subtraction with preaveraged/naked darkframe MLVs.
#~ --> Integrate openlut for 1D LUTs. 3D LUTs would only be used for gamut transforms, not gamut/gamma.
#~ --> More error checking.
#~ --> Test Mac compatibility with a *working* (with 10.7) mlv_dump...
#~ --> Documentation: PDF and Videos.

#~ MEDIUM PRIORITY
#~ --> Integrate openlut for gamut ops. Matrices would replace standard 3D LUTs altogether, and openlut would handle 3D LUTs.

#~ LOW
#~ --> Stats for .RAW files.


#~ FUTURE
#~ --> A GUI app, running libraw variants, which has a CLI backend, but can also output a convmlv config file.
#~     --> convmlv will always have more features - bash makes certain nasty things like ffmpeg filters available, as opposed to the "code it yourself" of true image array processing...
#~     --> But, a GUI is usable by the average non-nerd!! You know, the users of ML.


#BUG: Relative OUTDIR makes baxpixel generation fail if ./mlv2badpixels.sh doesn't exist. Should be fixed on all platforms.
#BIG BUG: Color Management is oversaturated, destructively so.
#~ --> See Nasty Hacks Part 1 - 3. FML :O.

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
VERSION="2.0.1" #Version string.
INPUT_ARGS=$(echo "$@") #The original input argument string.

if [[ $OSTYPE == "linux-gnu" ]]; then
	THREADS=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1)
elif [[ $OSTYPE == "darwin11" ]]; then
	THREADS=$(sysctl -n hw.ncpu)
else
	THREADS=4
fi

readlinkFMac() {
#We have a replica of readlink -f for macs everywhere!
	target=$1

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

}

setPaths() { #Repends on RES_PATH and PYTHON. Run this function if either is changed.
	MLV_DUMP="${RES_PATH}/mlv_dump" #Path to mlv_dump location.
	RAW_DUMP="${RES_PATH}/raw2dng" #Path to raw2dng location.
	CR_HDR="${RES_PATH}/cr2hdr" #Path to cr2hdr location.
	MLV_BP="${RES_PATH}/mlv2badpixels.sh"
	PYTHON_BAL="${RES_PATH}/balance.py"
	PYTHON_SRANGE="${RES_PATH}/sRange.py"
	BAL="${PYTHON} ${PYTHON_BAL}"
	SRANGE="${PYTHON} ${PYTHON_SRANGE}"
	COLOR_LUTS=("${RES_PATH}/color-core" "${RES_PATH}/color-ext") #One can add more with options, but these are the defaults.
	
	DCRAW="dcraw"
}

setDefaults() { #Set all the default variables. Run here, and also after each ARG run.
#DEPENDENCIES
	DEB_DEPS="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl" #Dependency package names (Debian). List with -K option.
	UBU_DEPS="imagemagick dcraw ffmpeg python3 python3-pip libimage-exiftool-perl" #Dependency package names (Ubuntu). List with -K option.
	FED_DEPS="ImageMagick dcraw ffmpeg python3 python-pip perl-Image-ExifTool" #Dependency package names (Fedora). List with -K option.
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


#PATHS
	RES_PATH="." #Current Directory by default.
	GCONFIG="${HOME}/convmlv.conf"
	LCONFIG="" #No local config by default.

	setPaths #Set all the paths using the current RES_PATH.

	OUTDIR="./raw_conv"
	isOutGen=false

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
	DEPTH="-W -6"
	DEPTH_OUT="-depth 16"
	WAVE_NOISE="" #Used to be NOISE_REDUC. Wavelet noise reduction.
	FOUR_COLOR=""
	CHROMA_SMOOTH="--no-cs"
	
#COLOR MANAGEMENT
	GAMMA="1 1" #As far as dcraw is concerned, output is linear.
	SPACE="5" #dcraw only outputs Linear XYZ. LUTs convert onwards.
	COLOR_GAMMA="lin" #STANDARD marks it such that it will correspond to the gamut
	COLOR_GAMUT="srgb"
	COLOR_VF="" #Standard (~2.4) sRGB LUT by default: ${CORE_LUT}/lin_xyz--srgb_srgb.cube . This is used in VF_FILTERS
	colorDesc=""

#FEATURES
	DUAL_ISO=false
	BADPIXELS=""
	BADPIXEL_PATH=""
	isBP=false
	DARKFRAME=""
	useDF=false
	DARK_PROC=""
	RES_DARK=""
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

setDefaults #Run now, but also later.

cVal() {
	echo -e "\033[1m\033[37m${1}\033[0m"
}

bVal() {
	echo -e "\033[1m\033[32m${1}\033[0m"
}

head() {
	echo -e "\033[1m${1}\033[0m"
}

iVal() {
	echo -e "\033[1m\033[33m${1}\033[0m"
}

help() {
less -R << EOF 
Usage:
	$(echo -e "\033[1m./convmlv.sh\033[0m [FLAGS] [OPTIONS] \033[2mfiles\033[0m")
	
$(head "INFO:")
	A program allowing you to develop ML files into workable formats. Many useful options are exposed.
	  --> Defaults: Compressed 16-bit Linear EXR. 10-bit Prores4444 MOV.
	  --> Color Defaults: Linear (1.0) Gamma on sRGB Gamut, using Camera White Balance.
	  
	  --> Acceptable Inputs: MLV, RAW (requires raw2dng), Folder containing DNGs.
	  --> Option Input: From command line or config file (specify with -C).
	  
	  --> Forum Post: http://www.magiclantern.fm/forum/index.php?topic=16799.
	  --> A note: BE CAREFUL WITH OPTIONS. Wrong values will give very strange errors. Read this page well!!
	  
	It's as simple or complex as you need it to be: 'convmlv -m <mlvfile>.mlv' is enough for good-looking output!
	
$(echo -e "$(head VERSION): ${VERSION}")
	
$(head "MANUAL DEPENDENCIES:")
	Place these in RES_PATH (see OPTIONS, BASIC). Keep in mind you also need dist. and pip packages.
	  --> See 'Dist Deps' and 'Python Deps'

	-- mlv_dump: Required binary. http://www.magiclantern.fm/forum/index.php?topic=7122.0
	-- color-core: Required folder of LUTs. See convmlv repository.
	-- sRange.py: Required script. See convmlv repository.
	
	-- raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0
	-- mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src
	-- cr2hdr: For Dual ISO Development. Two links: http://www.magiclantern.fm/forum/index.php?topic=16799.0
	-- balance.py: For Auto White Balance. See convmlv repository.
	-- color-ext: Extra LUTs, providing more color resources. See convmlv repository.

$(head "OPTIONS, BASIC:")
	-v, --version		$(bVal version) - Print out version string.
	-h, --help		$(bVal help) - Print out this help page.
	
	-C, --config		$(bVal config) - Designates config file to use.
	
	-o, --outdir <path>	$(cVal OUTDIR) - The path in which files will be placed.
	-P, --res-path <path>	$(iVal RES_PATH) - The path in which all manual dependencies are looked for.
	  --> Default: Current Directory.
	
	--dcraw <path>		$(cVal DCRAW) - The path to dcraw.
	--mlv-dump <path>	$(cVal MLV_DUMP) - The path to mlv_dump.
	--raw-dump <path>	$(cVal RAW_DUMP) - The path to raw2dng.
	--badpixels <path>	$(cVal MLV_BP) - The path to mlv2badpixels.sh (by dfort).
	--cr-hdr <path>		$(cVal CR_HDR) - The path to cr2hdr.
	--srange <path>	 	$(cVal SRANGE) - The path to sRange.py.
	--balance <path>	$(cVal BAL) - The path to balance.py.
	--python <path>		$(cVal PYTHON) - The path or command used to invoke Python 3. Default is python3 on Linux, python on Mac.
	
	-T, --threads [int]	$(cVal THREADS) - Override amount of utilized process threads. Default is MAX - 1.
	
	
$(head "OPTIONS, OUTPUT:")
	-i			$(cVal IMAGE) - Will output image sequence.
	
	-t [0:3]		$(cVal IMG_FMT) - Image output format.
	  --> 0: EXR (default), 1: TIFF, 2: PNG, 3: Cineon (DPX)."
	
	-m			$(cVal MOVIE) - Will output a Prores4444 file.
	
	-p [0:3]		$(cVal PROXY) - Create proxies alongside main output.
	  --> 0: No proxies (Default). 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.
	  
	  --> JPG proxy will always be in sRGB Gamma/sRGB Gamut. H.264 proxy is color managed.
	  --> JPG proxy *won't* be developed w/o IMAGE. H.264 proxy *will* be developed no matter what, if specified here.
	  --> Why? JPG is for potential use in editing. H.264 is for a quick visual preview of convmlv's output.
	
	-s [0%:100%]		$(cVal PROXY_SCALE) - the size, in %, of the proxy output.
	  --> Default: 50%.
	
	-k			$(cVal KEEP_DNGS) - Specify if you want to keep the DNG files.
	  --> Run convmlv on the top level folder of former output to reuse saved DNGs from that run!
	  
	-r <start>-<end>	$(cVal FRAME_RANGE) - Specify to process an integer frame range.
	  --> You may use the characters 's' and 'e', such that s = start frame, e = end frame.
	  --> Indexed from 0 to (# of frames - 1). Develops from 1 to ($ of frames)
	  --> A single number may be writted to develop that single frame.
	  --> DO NOT try to reuse DNGs while developing a larger frame range.
	
	
	--uncompress		$(cVal UNCOMP) - Turns off lossless image compression. Otherwise:
	  --> TIFF: ZIP, EXR: PIZ, PNG: lvl 0, DPX: RLE.
	
	
$(head "OPTIONS, RAW DEVELOPMENT:")
	-d [0:3]		$(cVal DEMO_MODE) - Demosaicing algorithm. Higher modes are slower + better.
	  --> 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.
	
	-f			$(cVal FOUR_COLOR) - Interpolate as RGBG. Fixes weirdness with VNG/AHD, at the cost of sharpness.
	
	-H [0:9]		$(cVal HIGHLIGHT_MODE) - Highlight management options.
	  --> 0: White, clipped highlights. 1: Unclipped but colored highlights. 2: The defail of 1, but adjusted to grey.
	  --> 3-9: Highlight reconstruction. Can cause flickering. Start at 5, then adjust to color (down) or to white (up).
	
	-c [0:3]		$(cVal CHROMA_SMOOTH) - Apply shadow/highlight chroma smoothing to the footage.
	  --> 0: None (default). 1: 2x2. 2: 3x3. 3: 5x5.
	  --> MLV input Only.
	
	-n [int]		$(cVal WAVE_NOISE) - Apply wavelet denoising.
	  --> Default: None. Subtle: 25. Medium: 50. Strong: 125.
	  
	-N <A>-<B>		$(cVal TEMP_NOISE) - Apply temporal denoising.
	  --> A: 0 to 0.3. B: 0 to 5. A reacts to abrupt noise (splotches), B reacts to noise over time (fast motion causes artifacts).
	  --> Subtle: 0.03-0.04. High: 0.15-0.04. High, Predictable Motion: 0.15-0.07
	  
	-Q [i-i:i-i]		$(cVal HQ_NOISE) - Apply 3D denoising filter.
	  --> In depth explanation: https://mattgadient.com/2013/06/29/in-depth-look-at-de-noising-in-handbrake-with-imagevideo-examples/ .
	  --> Spacial/Temporal (S/T). S will soften/blur/smooth, T will remove noise without doing that but may create artifacts.
	  --> Luma/Chroma (L/C). L is the detail, C is the color. Each one's denoising may be manipulated Spacially or Temporally.
	  
	  --> Option Value: <LS>-<CS>:<LT>-<CT>
	  --> Weak: 2-1:2-3. Medium: 3-2:2-3. Strong: 7-7:5-5
	  
	  --> DONT combine with TEMP_NOISE.
	
	-O [i-i-i-i]		$(cVal REM_NOISE) - Yet another spatial denoiser, with 4 choices of 24 modes.
	  --> See https://ffmpeg.org/ffmpeg-filters.html#removegrain for list of modes.
	  
	  --> Option Value: <mode1>-<mode2>-<mode3>-<mode4>
	  --> I truly cannot tell you what values will be helpful to you; there are too many... Look at the link!
	
	--shallow 		$(cVal SHALLOW) - Output smaller, 8-bit files.
	  --> Read why this is a bad idea: http://www.cambridgeincolour.com/tutorials/bit-depth.htm
	
	
$(head "OPTIONS, COLOR:")
	-g [0:4]		$(cVal GAMMA) - Output gamma. A curve applied to the output, for easier viewing/grading.
	  --> 0: Standard (Around 2.2). 1: Linear (Default).
	  --> Requires color-ext: 2: Cineon. 3: C-Log2 4: S-Log3
	  
	  --> "Standard" grades to the gamut specification, and to 2.2 if that's not given.
	  
	-G [0:6]		$(cVal GAMUT) - Output gamut. The range of colors that can exist in the output.
	  --> 0: sRGB (Default). 1: Adobe RGB. 2: Rec.709. 3: XYZ (Always Linear Gamma).
	  --> Requires color-ext: 4: Rec2020 5: DCI-P3 6: Sony S-Gamut3.cine

	-w [0:2]		$(cVal WHITE) - This is a modal white balance setting.
	  --> 0: Auto WB (requires balance.py). 1: Camera WB (default). 2: No Change.
	  --> AWB uses the Grey's World algorithm.
	  
	-A [i:i:i:i]		$(cVal SHARP) - Lets you sharpen, or blur, your footage.
	  --> BE CAREFUL. Wrong values will give you strange errors.
	  --> Size/Strength (S/T). S is the size of the sharpen/blur effect, T is the strength of the sharpen/blur effect.
	  --> Luma/Chroma (L/C). L is the detail, C is the color. Luma sharpening more effective.
	
	  --> Option Value: <LS>:<LT>:<CS>:<CT>
	  --> LS and CS must be ODD, between 3 and 63. Negative LT/CT values blur, while positive ones sharpen.
	  --> Strong Sharp: 7:3:7:3 Strong Blur: 7,-3:7,-3. Medium Sharp: 5:1:3:0
	  
	-l <path>		$(cVal LUT) - Specify a LUT to apply after Color Management.
	  --> Supports cube, 3dl, dat, m3d.
	  --> Specify -l multiple times, to apply multiple LUTs in sequence.
	  
	-S [int]		$(cVal SATPOINT) - Specify the 14-bit uint saturation point of your camera. You don't usually need to.
	  --> Worth setting globally, as it's a per-camera setting. Must be correct for highlight reconstruction/unclipped highlights.
	  --> Lower from 15000 if -H1 yields purple highlights, until they turn white.
	  --> You can determine the optimal value using the max pixel value of 'dcraw -D -j -4 -T'.
	
	--white-speed [int]	$(cVal WHITE_SPD) - Manually specify samples used to calculate AWB.
	
	--allow-white-clip	$(cVal WHITE_CLIP) - Let the White Balance multipliers clip.
	
	
$(head "OPTIONS, FEATURES:")
	-D			$(cVal DESHAKE) - Auto-stabilize the video using ffmpeg's "deshake" module.
	  --> You may wish to crop/scale the output later, to avoid edge artifacts.
	
	-u			$(cVal DUAL_ISO) - Process as dual ISO.
	  --> Requires cr2hdr.
	
	-b			$(cVal BADPIXELS) - Fix focus pixels issue using dfort's script.
	  --> Requires mlv2badpixels.sh.
	
	-a <path>		$(cVal BADPIXEL_PATH) - Use your own .badpixels file. Does NOT require mlv2badpixels.sh
	  --> How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686
	
	-F <path>		$(cVal DARKFRAME) - This is the path to a "dark frame MLV"; effective for noise reduction.
	  --> How to: Record 5 sec w/lens cap on & same settings as footage. Pass MLV in here.
	  --> If the file extension is '.darkframe', the file will be used as a preaveraged dark frame.
	
	-R <path>		$(bVal darkframe_output) - Specify to create a .darkframe file from passed in MLV.
	 --> Usage: 'convmlv -R <path> <input>.MLV'
	 --> Averages <input>.MLV to create <path>.darkframe.
	 --> THE .darkframe EXTENSION IS ADDED FOR YOU.
	
	
$(head "OPTIONS, INFO:")
	-q			$(bVal settings) - Output MLV settings.
	
	-K [0:3]		$(bVal "Dist Deps") - Output package dependecies, for use with common package managers.
	  --> 0: Debian, 1: Ubuntu, 2: Fedora, 3: Homebrew (Mac)
	
	  --> Deps Install (Debian): sudo apt-get install \$(./convmlv.sh -K 0)
	  --> Deps Install (Ubuntu): sudo apt-get install \$(./convmlv.sh -K 1)
	  --> Deps Install (Fedora): sudo yum install \$(./convmlv.sh -K 2)
	  --> Deps Install (Homebrew Mac): brew install \$(./convmlv.sh -K 3)
	
	-Y			$(bVal "Python Deps") - Lists Python dependencies. Works directly with pip.
	  -->Install (Cross-Platform): sudo python3 -m pip install $ (./convmlv -Y)
	
	-M			$(bVal "Manual Deps") - Lists manual dependencies, which must be downloaded by hand.
	  --> Manually place all in RES_PATH. See http://www.magiclantern.fm/forum/index.php?topic=16799.0 .
	
	
$(head "COLOR MANAGEMENT:")
	$(bold INTRO) Images aren't simple. They are often stored, processed, and viewed as a result of complex transformations usually called, 
	in applications, color management. Understanding it is required as a colourist, and encouraged as a DPs and Cinematographers.
	
	--> Intro: http://www.cambridgeincolour.com/tutorials/color-management1.htm
	--> Understanding Gamma: http://www.cambridgeincolour.com/tutorials/gamma-correction.htm
	--> Color Spaces: http://www.cambridgeincolour.com/tutorials/color-spaces.htm
	--> Conversions: http://www.cambridgeincolour.com/tutorials/color-space-conversion.htm
	--> Monitor Calibration: http://www.cambridgeincolour.com/tutorials/monitor-calibration.htm
	
	$(bold "PIPELINE") convmlv is a color managed application, designed to retain quality from RAW footage:
	
		-- mlv_dump writes camera-specific color transformation matrices as metadata in developed DNGs.
			--> This defines the camera's gamut.
		-- dcraw applies these matrices, then transforms the newly developed image to the super-wide XYZ colorspace.
			--> All color detail is preserved, and if now in a well-defined colorspace.
			--> No gamma has been applied - the image is now Linear XYZ.
		-- ffmpeg applies the specified (up to) x64 resolution 3D LUTs, in .cube format.
			--> Use -g and -G to specify Gamma/Gamut combinations.
			--> The output employs DATA, not LEGAL, values. The resulting image is flatter, but retains all shadow/highlight detail.
			--> -l specified LUTs are applied afterwards.
	
	$(bold "3D LUTS") The included LUTs, found in the convmlv repository, are key to convmlv's color management solution:
		-- color-core: The required LUTs, including sRGB (default), Adobe RGB, and Rec709 in Standard and Linear gamma.
		-- color-ext: Optional LUTs, including Rec2020, DCI-P3, etc. in Standard/Linear gammas, but also in Log formats.
		
	$(bold "Create Your Own LUTs") using LUTCalc, for any grading format output: https://cameramanben.github.io/LUTCalc/ (watch his tutorials).
	 --> Note that convmlv only accepts up to 64x64x64 LUTs. You can resize LUTs using pylut (https://pypi.python.org/pypi/pylut).
	 --> The pylut command to resize is 'pylut <yourx65lut>.cube --resize 64'. Alternatively, you can use pylut from Python (2X only).
	 
	 --> I reccommend Legal --> Data LUTs, as this conserves shadow/highlight detail for grading. Legal --> Legal looks better, but with detail loss.
	
	
$(head "CONFIG FILE:")
	Config files, another way to specify options, can save you time & lend you convenience in production situations.
	
	$(echo -e "\033[1mGLOBAL\033[0m"): $HOME/convmlv.conf
	$(echo -e "\033[1mLOCAL\033[0m"): Specify -C/--config.
	
	
	$(echo -e "\033[1mSYNTAX:\033[0m")
		Most options listed above have an uppercased VARNAME, ex. OUTDIR. You can specify such options in config files, as such:
		
			<VARNAME> <VALUE>
			
		One option per line only. Indentation by tabs or spaces is allowed, but not enforced.
			
		$(echo -e "\033[1mComments\033[0m") Lines starting with # are comments.
		
		You may name a config using:
		
			CONFIG_NAME <name>
			
		$(echo -e "\033[1mFlags\033[0m") If the value is a true/false flag (ex. IMAGE), simply specifying VARNAME is enough. There is no VALUE.
	
	$(echo -e "\033[1mOPTION ORDER OF PRECEDENCE\033[0m") Options override each other as such:
		-LOCAL options overwrite GLOBAL options.
		-COMMAND LINE options overwrite LOCAL & GLOBAL options.
		-FILE SPECIFIC options overwrite ALL ABOVE options.
	
	
	$(echo -e "\033[1mFile-Specific Block\033[0m"): A LOCAL config file lets you specify options for specific input names:
	
		/ <TRUNCATED INPUTNAME>
			...options here will only be 
		*
		
		You must use the truncated (no .mlv or .raw) input name after the /. Nested blocks will fail.
		
		With a single config file, you can control the development options of multiple inputs as specifically and/or generically
		as you want. Batch developing everything can then be done with a single, powerful commmand.
		


Contact me with any feedback or questions at convmlv@sofusrose.com, PM me (so-rose) on the ML forums, or post on the thread!
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
				[Nn]* ) echo -e "\n\033[0;31m\033[1mDirectory ${path} won't be created.\033[0m\n"; cont=true; `$cleanup`; break
				;;
				[Qq]* ) echo -e "\n\033[0;31m\033[1mHalting execution. Directory ${path} won't be created.\033[0m\n"; `$cleanup`; exit 1;
				;;
				* ) echo -e "\033[0;31m\033[1mPlease answer yes or no.\033[0m\n"
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

invOption() {
	str=$1
	
	echo -e "\033[0;31m\033[1m${str}\033[0m"
	
	echo -e "\n\033[1mCleaning Up.\033[0m\n\n"
	
	#Delete tmp
	rm -rf $TMP
	
	exit 1
}

evalConf() {
	file=$1 #The File to Parse
	argOnly=$2 #If true, will only use file-specific blocks. If false, will ignore file-specific blocks.
	CONFIG_NAME="None"
	
	if [[ -z $file ]]; then return; fi
    if [[ ! -f $file ]]; then return; fi
	
	fBlock=false #Whether or not we are in a file-specific block.
	fID="" #The name of the file-specific block we're in.
	
	while IFS="" read -r line || [[ -n "$line" ]]; do
		line=$(echo "$line" | sed -e 's/^[ \t]*//') #Strip leading tabs/whitespaces.
		
		if [[ `echo "${line}" | cut -c1-1` == "#" ]]; then continue; fi #Ignore comments
		
		if [[ `echo "${line}" | cut -c1-1` == "/" ]]; then
			if [[ $fBlock == true ]]; then echo -e "\n\033[0;31m\033[1mWARNING: Nested blocks!!!\033[0m"; fi
			fBlock=true
			fID=`echo "${line}" | cut -d$' ' -f2`
			continue
		fi #Enter a file-specific block with /, provided the argument name is correct.
		
		if [[ `echo "${line}" | cut -c1-1` == "*" ]]; then fBlock=false; fi #Leave a file-specific block.
		
		#~ echo $argOnly $fBlock $fID ${TRUNC_ARG%.*} `echo "${line}" | cut -d$' ' -f1`
		if [[ ($argOnly == false && $fBlock == false) || ( ($argOnly == true && $fBlock == true) && $fID == ${TRUNC_ARG%.*} ) ]]; then #Conditions under which to write values.
			case `echo "${line}" | cut -d$' ' -f1` in
				"CONFIG_NAME") CONFIG_NAME=`echo "${line}" | cut -d$' ' -f2` #Not doing anything with this right now.
				;;
				"OUTDIR") OUTDIR=`echo "${line}" | cut -d$' ' -f2`
				;;
				"RES_PATH") RES_PATH=`echo "${line}" | cut -d$' ' -f2`; setPaths
				;;
				"DCRAW") DCRAW=`echo "${line}" | cut -d$' ' -f2`
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
				;;
			F)
				DARKFRAME=`echo "${line}" | cut -d$' ' -f2`;
					
				if [ ! -f $DARKFRAME ]; then invOption "F: Invalid Darkframe: ${DARKFRAME}"; fi
					
				useDF=true
				;;
			R)
				MK_DARK=true
				DARK_OUT=${OPTARG}
				;;
			
			
			q)
				SETTINGS_OUTPUT=true
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

checkDeps() {
		argBase="$(basename "$ARG")"
		argExt="${argBase##*.}"
		argTrunc="${argBase%.*}"
		
		nFound() { #Prints: ${type} ${name} not found! ${exec_instr}.\n\t${down_instr}
			type=$1
			name="$2"
			exec_instr=$3
			down_instr=$4
			
			if [[ -z $down_instr ]]; then
				echo -e "\033[1;31m${type} \033[0;1m${name}\033[1;31m not found! ${exec_instr}.\033[0m"
			else
				echo -e "\033[1;31m${type} \033[0;1m${name}\033[1;31m not found! ${exec_instr}.\033[0m\n------> ${down_instr}\n"
			fi
		}
		
		#Argument Checks
		if [ ! -f $ARG ] && [ ! -d $ARG ]; then
			nFound "File" "${ARG}" "Skipping File"
			let ARGNUM--; continue
		fi
		
		if [[ ! -d $ARG && ! ( $argExt == "MLV" || $argExt == "mlv" || $argExt == "RAW" || $argExt == "raw" ) ]]; then
			echo -e "\033[0;31m\033[1mFile ${ARG} has invalid extension!\033[0m\n"
			let ARGNUM--; continue
		fi
		
		if [[ ( ( ! -f $ARG ) && $(ls -1 ${ARG%/}/*.[Dd][Nn][Gg] 2>/dev/null | wc -l) == 0 ) && ( `folderName ${ARG}` != $argTrunc ) ]]; then
			echo -e "\033[0;31m\033[1mFolder ${ARG} contains no DNG files!\033[0m\n"
			let ARGNUM--; continue
		fi
		
		if [ ! -d $ARG ] && [[ $(echo $(wc -c ${ARG} | xargs | cut -d " " -f1) / 1000 | bc) -lt 1000 ]]; then #Check that the file is not too small.
			cont=false
			while true; do
                #xargs easily trims the cut statement, which has a leading whitespace on Mac.
				read -p "${ARG} is unusually small at $(echo "$(echo "$(wc -c ${ARG})" | xargs | cut -d$' ' -f1) / 1000" | bc)KB. Continue, skip, remove, or quit? [c/s/r/q] " csr
				case $csr in
					[Cc]* ) "\n\033[0;31m\033[1mContinuing.\033[0m\n"; break
					;;
					[Ss]* ) echo -e "\n\033[0;31m\033[1mSkipping.\033[0m\n"; cont=true; break
					;;
					[Rr]* ) echo -e "\n\033[0;31m\033[1mRemoving ${ARG}.\033[0m\n"; cont=true; rm $ARG; break
					;;
					[Qq]* ) echo -e "\n\033[0;31m\033[1mQuitting.\033[0m\n"; isExit=true; break
					;;
					* ) echo -e "\033[0;31m\033[1mPlease answer continue, skip, or remove.\033[0m\n"
					;;
				esac
			done
			
			if [ $cont == true ]; then
				let ARGNUM--; continue
			fi
		fi
		
		#Essentials
		if [ ! -f $MLV_DUMP ]; then
			nFound "Binary" "${MLV_DUMP}" "Execution will halt" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=7122.0."
			isExit=true
		fi
		if [ ! -d ${COLOR_LUTS[0]} ]; then
			nFound "Folder" "color-core" "Execution will halt" "Download from convmlv repository."
			isExit=true
		fi
		if [ ! -f $PYTHON_SRANGE ]; then
			nFound "Python Script" "${PYTHON_SRANGE}" "Execution will halt" "Download from convmlv repository."
			isExit=true
		fi
		
		cmdExists() { if type -P "$1" &> /dev/null || [ -x "$1" ]; then echo true; else echo false; fi }
		
		#Basic Options - Dist Deps
		if [[ $(cmdExists "$DCRAW") != true ]]; then
			nFound "Command" "$DCRAW" "Execution will halt" "dcraw not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "$PYTHON") != true ]]; then
			nFound "Command" "$PYTHON" "Execution will halt" "Python was not installed correctly. Install version 3.X, or see PYTHON in the OPTIONS, BASIC section of 'convmlv -h' for custom path."
			isExit=true
		fi
		if [[ $(cmdExists "$PYTHON") == true && $($PYTHON -c 'import sys; print(sys.version_info[0])') != 3 ]]; then
			nFound "Python Version" "3.X" "Execution will halt" "Your python version is $($PYTHON -c "import sys; print('.'.join(str(x) for x in sys.version_info[0:3]))") - convmlv requires 3.X. Typically, you must install the 'python3' package; else you can set set PYTHON in the OPTIONS, BASIC section of 'convmlv -h'."
		fi
		if [[ $(cmdExists "convert") != true ]]; then
			nFound "Command" "convert" "Execution will halt" "ImageMagick not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "ffmpeg") != true ]]; then
			nFound "Command" "ffmpeg" "Execution will halt" "ffmpeg not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		if [[ $(cmdExists "exiftool") != true ]]; then
			nFound "Command" "exiftool" "Execution will halt" "exiftool not installed correctly - See Dist Deps in the OPTIONS, INFO section of 'convmlv -h'."
			isExit=true
		fi
		
		#Optionals
		if [ ! -f $RAW_DUMP ]; then
			nFound "Binary" "${RAW_DUMP}" "Execution will continue without .RAW processing capability" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=5404.0."
		fi
		if [ ! -f $MLV_BP ]; then
			nFound "SH Script" "${MLV_BP}" "Execution will continue without badpixel removal capability" "Get it here: https://bitbucket.org/daniel_fort/ml-focus-pixels/src"
		fi
		if [ ! -f $CR_HDR ]; then
			nFound "Binary" "${CR_HDR}" "Execution will continue without Dual ISO processing capability" "Get it here: http://www.magiclantern.fm/forum/index.php?topic=7139.0"
		fi
		if [ ! -f $PYTHON_BAL ]; then
			nFound "Python Script" "${PYTHON_BAL}" "Execution will continue without AWB" "Download from convmlv repository."
		fi
		if [ ! -d ${COLOR_LUTS[1]} ]; then
			nFound "Folder" "color-ext" "Execution will continue without extra gamma/gamut options." "Download from convmlv repository."
		fi
		
		if [[ $isExit == true ]]; then
			echo -e "\033[0;33m\033[1mPlace all downloaded files in RES_PATH - ${RES_PATH} - or give specific paths with the relevant arguments/config VARNAMEs (see 'convmlv -h'). Also, make sure they're executable (run 'chmod +x file').\033[0m\n"
			exit 1
		fi
		
		
		#Option Checking - ideally, we do all of these. For now, I'm bored of it...
			#Check wavelet NR - WAVE_NOISE
			#Check TEMP_NOISE
			#Check HQ_NOISE
			#Check REM_NOISE
			#Check SHARP
			#Check SATPOINT
			#Check WHITE_SPD
			#Check BADPIXEL_PATH
			#Check LUT size.
			#badpixel info.
}

bold() {
	echo -e "\033[1m${1}\033[0m"
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
$(bold Resolution): ${RES_IN}
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
	RES_IN=`echo "$camDump" | grep "Res" | sed 's/[[:alpha:] ]*:  //'`
	ISO=`echo "$camDump" | grep 'ISO' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f2`
	APERTURE=`echo "$camDump" | grep 'Aperture' | sed 's/[[:alpha:] ]*:    //' | cut -d$'\n' -f1`
	LEN_FOCAL=`echo "$camDump" | grep 'Focal Len' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
	SHUTTER=`echo "$camDump" | grep 'Shutter' | sed 's/[[:alpha:] ]*:   //' | grep -oP '\(\K[^)]+' |  cut -d$'\n' -f1`
	REC_DATE=`echo "$camDump" | grep 'Date' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	REC_TIME=`echo "$camDump" | grep 'Time:        [0-2][0-9]\:*' | sed 's/[[:alpha:] ]*:        //' | cut -d$'\n' -f1`
	KELVIN=`echo "$camDump" | grep 'Kelvin' | sed 's/[[:alpha:] ]*:   //' | cut -d$'\n' -f1`
}

rawSet() { #To be implemented maybe - exiftool? Or raw_dump? ...
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

dngSet() { #Set as many options as the RAW spec will allow. Grey out the rest.
	dngLoc=$1
	
	if [[ -z $dngLoc ]]; then dngLoc="${ARG}"; fi
	
	for dng in $dngLoc/*.dng; do
		dataDNG="$(pwd)/.datadng.dng"
		cp $dng $dataDNG
		break
	done
	FPS=24 #Standard FPS.
	
	#Frames is taken care of.
	CAM_NAME=$(exiftool -UniqueCameraModel -s -s -s $dataDNG)
	RES_IN=$(exiftool -ImageSize -s -s -s $dataDNG)
	ISO=$(exiftool -UniqueCameraModel -s -s -s $dataDNG)
	APERTURE=$(exiftool -ApertureValue -s -s -s $dataDNG)
	LEN_FOCAL=$(exiftool -FocalLength -s -s -s $dataDNG)
	SHUTTER=$(exiftool -ShutterSpeed -s -s -s $dataDNG)
	REC_DATE=$(echo "$(exiftool -DateTimeOriginal -s -s -s $dataDNG)" | cut -d$' ' -f1)
	REC_TIME=$(echo "$(exiftool -DateTimeOriginal -s -s -s $dataDNG)" | cut -d$' ' -f2)
	KELVIN="Unknown"
	
	rm $dataDNG
}

if [ $# == 0 ]; then
	echo -e "\033[0;31m\033[1mNo arguments given.\033[0m\n\tType 'convmlv -h/--help' to see help page, or 'convmlv -v/--version' for current version string."
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

trap "rm -rf ${TMP}; exit 1" INT #TMP will be removed if you CTRL+C.
for ARG in "${FILE_ARGS_ITER[@]}"; do #Go through FILE_ARGS_ITER array, copied from parsed $@ because $@ is going to be changing on 'set --'
	if [[ $OSTYPE == "linux-gnu" ]]; then
		ARG="$(readlink -f $ARG)"  >/dev/null 2>/dev/null #Relative ARG fixed properly on Linux, as readlink only exists in UNIX.
	elif [[ $OSTYPE == "darwin11" ]]; then
		ARG="$(readlinkFMac $ARG)"  >/dev/null 2>/dev/null #Mac relative OUTDIR uses the special readlinkFMac :)
	fi
	
#The Very Basics
	BASE="$(basename "$ARG")"
	EXT="${BASE##*.}"
	if [[ "${EXT}" == ".${BASE}" ]]; then EXT=""; fi #This means the input is a folder, which has no extension.
	DIRNAME=$(dirname "$ARG")
	TRUNC_ARG="${BASE%.*}"
	SCALE=`echo "($(echo "${PROXY_SCALE}" | sed 's/%//') / 100) * 2" | bc -l` #Get scale as factor for halved video, *2 for 50%
	setBL=true
	
	joinArgs() { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }
#Evaluate convmlv.conf configuration file for file-specific blocks.
	evalConf "$LCONFIG" true
#Check that things exist.
	checkDeps
	
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
	
#Potentially Print Settings
	if [ $SETTINGS_OUTPUT == true ]; then
		if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
			# Read the header for interesting settings :) .
			mlvSet
			
			echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m: ${ARG}\n"
			prntSet
			continue
		elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
			rawSet
			
			echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m\033[0m: ${ARG}\n"
			prntSet
			continue
		elif [ -d $ARG ]; then
			dngSet
			
			echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m\033[0m: ${ARG}\n"
			prntSet
			continue
		else
			echo -e "Cannot print settings from ${ARG}; it's not an MLV file!"
			continue
		fi
	fi
	
	if [[ $MK_DARK == true ]]; then 
		echo -e "\n\033[1m\033[0;32m\033[1mAveraging Darkframe File\033[0m: ${ARG}"
		$MLV_DUMP -o $DARK_OUT $ARG 2>/dev/null 1>/dev/null
		echo -e "\n\033[1m\033[1mWrote Darkframe File\033[0m: ${DARK_OUT}\n"
		continue
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
	if [[ $OSTYPE == "linux-gnu" ]]; then
		OUTDIR="$(readlink -f $OUTDIR)"  >/dev/null 2>/dev/null #Relative Badpixel OUTDIR fixed properly on Linux.
	elif [[ $OSTYPE == "darwin11" ]]; then
		OUTDIR="$(readlinkFMac $OUTDIR)"  >/dev/null 2>/dev/null #Mac relative OUTDIR uses the special readlinkFMac :)
	fi
	
	if [ $OUTDIR != $PWD ] && [ $isOutGen == false ]; then
		mkdir -p $OUTDIR #NO RISKS. WE REMEMBER THE LUT.py. RIP ad-hoc HALD LUT implementation :'( .
		isOutGen=true
	fi
	
	FILE="${OUTDIR}/${TRUNC_ARG}"
	TMP="${FILE}/tmp_${TRUNC_ARG}"
	
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
		
		setRange
		
		i=1
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
		i=0
		t=0
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
	
#MANUAL SANDBOXING - see note at the header of the loop.
	set -- $INPUT_ARGS #Reset the argument input for reparsing again.
	setDefaults #Hard reset everything.
	OPTIND=1
	
	evalConf "$GCONFIG" false #Rearse global config file.
	parseArgs "$@" #First, parse args all to set LCONFIG.
	shift $((OPTIND-1))

	evalConf "$LCONFIG" false #Parse local config file.
	set -- $INPUT_ARGS #Reset the argument input for reparsing again, over the local config file.
	OPTIND=1
	
	parseArgs "$@"
	shift $((OPTIND-1))
	
	let ARGNUM--
done

exit 0
