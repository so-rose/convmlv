#!/bin/bash

#desc: The help function lives here, as well as helper functions thereof.

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
	-P, --bin-path <path>	$(iVal BIN_PATH) - The path in which all binary dependencies are looked for.
	  --> Default: ./binaries (the folder binaries in current folder).
	  --> Source Code: These components will be looked for at <location of convmlv.sh>/src.
	
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
