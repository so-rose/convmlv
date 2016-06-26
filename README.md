# convmlv #

MLV/RAW/DNG to Image/Movie and Proxy
=======
See [http://www.magiclantern.fm/forum/index.php?topic=16799.0](http://www.magiclantern.fm/forum/index.php?topic=16799.0) for more info.

**The pdf found in the source, under docs->docs.pdf, is very outdated. Use the help text below.**

Help page is below:

```text

Usage:
	./convmlv.sh [FLAGS] [OPTIONS] files
	
INFO:
	A script allowing you to develop ML files into workable formats. Many useful options are exposed.
	  -->Image Defaults: Compressed 16-bit Linear EXR.
	  -->Acceptable Inputs: MLV, RAW, DNG Folder.
	  -->Option Input: From command line or config file.
	
VERSION: 1.9.2
	
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
	
	-g [0:4]		SPACE - Output color transformation.
	  --> 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.
	
	--shallow 		SHALLOW - Output 8-bit files.
	
	
OPTIONS, COLOR:
	-w [0:2]		WHITE - This is a modal white balance setting.
	  --> 0: Auto WB. 1: Camera WB (default). 2: No Change.
	  
	-l <path>		LUT - Specify a LUT to apply.
	  --> Supports cube, 3dl, dat, m3d.
	  
	-S [int]		SATPOINT - Specify the 14-bit saturation point of your camera.
	  --> Lower if -H1 yields purple highlights. Must be correct for highlight reconstruction.
	  --> Determine using the max value of 'dcraw -D -j -4 -T'
	
	--white-speed [int]	WHITE_SPD - Samples used to calculate AWB
	
	--allow-white-clip	WHITE_CLIP - Let White Balance multipliers clip.
	
	
OPTIONS, FEATURES:
	-u			DUAL_ISO - Process as dual ISO.
	
	-b			BADPIXELS - Fix focus pixels issue using dfort's script.
	
	-a <path>		BADPIXEL_PATH - Use your own .badpixels file.
	  --> How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686
	
	-F <path>		DARKFRAME - This is the path to a "dark frame MLV"; effective for noise reduction.
	  --> How to: Record 5 sec w/lens cap on & same settings as footage. Pass MLV in here.
	  --> If the file extension is '.darkframe', the file will be used as the preaveraged dark frame.
	
	-R <path>		dark_out - Specify to create a .darkframe file from passed in MLV.
	 --> Outputs <arg>.darkframe file to <path>.
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
	You do not need to type in all the arguments each time: Config files, another way to specify options, can save you time & lend
	you convenience in production situations.
	
	GLOBAL: /home/sofus/convmlv.conf
	LOCAL: Specify -C/--config.

	Some options have an uppercased VARNAME, ex. OUTDIR. In a convmlv config file, you can specify this option
	in the following format, line by line:
		<VARNAME> <VALUE>
		
	If the value is a true/false flag, simply specifying VARNAME is enough. Otherwise, normal rules for the value applies.
	
	Options override each other as such:
	-LOCAL overrides GLOBAL config.
	-Passed arguments override both configs.
	-Lines starting with # are comments.
	-Name a config using the VARNAME: CONFIG_NAME <name>
	
	
	File-Specific Block: A LOCAL config file lets you specify options for specific input names:
		/ <TRUNCATED INPUTNAME>
			...specify options
		*
		
	File-Specific Blocks override all other options. This allows one to create
	a single config file to batch-develop several input files/folders at once, after deciding how each one should
	look/be configured individually.
	
	Notes on Usage:
	-You must use the truncated (no .mlv or .raw) input name after the /.
	-No nested blocks.
	-Indentation by tabs or spaces is allowed, but not enforced.	-w [0:2]		WHITE - This is a modal white balance setting.
	  --> 0: Auto WB. 1: Camera WB (default). 2: No Change.
	  
	-l <path>		LUT - Specify a LUT to apply.
	  --> Supports cube, 3dl, dat, m3d.
	  --> LUT cannot be applied to EXR sequences.
	  
	-S [int]		SATPOINT - Specify the 14-bit saturation point of your camera.
	  --> Lower if -H1 yields purple highlights. Must be correct for highlight reconstruction.
	  --> Determine using the max value of 'dcraw -D -j -4 -T'
	
	--white-speed [int]	WHITE_SPD - Samples used to calculate AWB
	
	--allow-white-clip	WHITE_CLIP - Let White Balance multipliers clip.
	
	
OPTIONS, FEATURES:
	-u			DUAL_ISO - Process as dual ISO.
	
	-b			BADPIXELS - Fix focus pixels issue using dfort's script.
	
	-a <path>		BADPIXEL_PATH - Use your own .badpixels file.
	  --> How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686
	
	-F <path>		DARKFRAME - This is the path to a "dark frame MLV"; effective for noise reduction.
	  --> How to: Record 5 sec w/lens cap on & same settings as footage. Pass MLV in here.
	  --> If the file extension is '.darkframe', the file will be used as the preaveraged dark frame.
	
	-R <path>		dark_out - Specify to create a .darkframe file from passed in MLV.
	 --> Outputs <arg>.darkframe file to <path>.
	 --> THE .darkframe EXTENSION IS ADDED FOR YOU.
	
	
OPTIONS, INFO:
	-q			Output MLV settings.
	
	-K			Debian Package Deps - Output package dependecies.
	  --> Install (Debian only): sudo apt-get install $ (./convmlv -K)
	
	-Y			Python Deps - Lists Python dependencies. Works directly with pip.
	  -->Install (Linux): sudo pip3 install $ (./convmlv -Y)
	
	-N			Manual Deps - Lists manual dependencies, which must be downloaded by hand.
	  --> There's no automatic way to install these. See http://www.magiclantern.fm/forum/index.php?topic=16799.0 .
	
CONFIG FILE:
	You do not need to type in all the arguments each time: Config files, another way to specify options, can save you time & lend
	you convenience in production situations.
	
	GLOBAL: /home/sofus/convmlv.conf
	LOCAL: Specify -C/--config.

	Some options have an uppercased VARNAME, ex. OUTDIR. In a convmlv config file, you can specify this option
	in the following format, line by line:
		<VARNAME> <VALUE>
		
	If the value is a true/false flag, simply specifying VARNAME is enough. Otherwise, normal rules for the value applies.
	
	Options override each other as such:
	-LOCAL overrides GLOBAL config.
	-Passed arguments override both configs.
	-Lines starting with # are comments.
	-Name a config using the VARNAME: CONFIG_NAME <name>
	
	
	File-Specific Block: A LOCAL config file lets you specify options for specific input names:
		/ <TRUNCATED INPUTNAME>
			...specify options
		*
		
	File-Specific Blocks override all other options. This allows one to create
	a single config file to batch-develop several input files/folders at once, after deciding how each one should
	look/be configured individually.
	
	Notes on Usage:
	-You must use the truncated (no .mlv or .raw) input name after the /.
	-No nested blocks.
	-Indentation by tabs or spaces is allowed, but not enforced.
```
