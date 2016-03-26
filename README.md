# convmlv #

MLV to TIFF/ProRes and Proxy ProRes/H.264
=======
See [http://www.magiclantern.fm/forum/index.php?topic=16799.0](http://www.magiclantern.fm/forum/index.php?topic=16799.0) for more info.

Help page is below:

```text

Usage:
	./convmlv.sh [OPTIONS] mlv_files

INFO:
	A script allowing you to convert .MLV, .RAW, or a folder with a DNG sequence into a sequence/movie
	with optional proxies. Many useful options are exposed, including formats (EXR by default).

DEPENDENCIES: *If you don't use a feature, you don't need the dependency. Don't use a feature without the dependency.
	-mlv_dump: For DNG extraction from MLV. http://www.magiclantern.fm/forum/index.php?topic=7122.0
	-raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0
	-mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src
	-dcraw: For RAW development.
	-ffmpeg: For video creation.
	-ImageMagick: Used for making proxy sequence.
	-Python 3 + libs: Used for auto white balance.
	-exiftool + xxd: Used in mlv2badpixels.sh.

VERSION: 1.7.1

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

	-f[0:3]   IMG_FMT - Create a sequence of <format> format, instead of a TIFF sequence.
	  --> 0: EXR (default), 1: TIFF, 2: PNG, 3: Cineon (DPX).

	-c   COMPRESS - Specify to automatically compress the image sequence.
	  --> TIFF: ZIP (best for 16-bit), PIZ for EXR (best for grainy images), PNG: lvl 9 (zlib deflate), DPX: RLE.
	  --> EXR's piz compression tends to be fastest + best.

	-m   MOVIE - Specify to create a Prores4444 video.

	-p[0:3]   PROXY - Specifies the proxy mode. 0 is default.
	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.
	  --> Proxies won't be developed without the main output - ex. JPG proxies require -i.

	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output.
	  --> Use -s<percentage>% (no space). 50% is default.

	-k   KEEP_DNGS - Specify if you want to keep the DNG files.
	  --> Besides testing, this makes the script a glorified mlv_dump...


OPTIONS, RAW DEVELOPMENT:
	-u    DUAL_ISO - Process file as dual ISO.

	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default.
	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.

	-r   FOUR_COLOR - Interpolate as four colors. Can often fix weirdness with VNG/AHD.

	-H[0:9]   HIGHLIGHT_MODE - 2 looks the best, without major modifications. 0 is also a safe bet.
	  --> Use -H<number> (no space). 0 clips. 1 allows colored highlights. 2 adjusts highlights to grey.
	  --> 3 through 9 do highlight reconstruction with a certain tone. See dcraw documentation.

	-b   BADPIXELS - Fix focus pixels issue using dfort's script.
	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src.

	-a<path>   BADPIXEL_PATH - Use, appending to the generated one, your own .badpixels file. REQUIRES -b.
	  --> Use -a<path> (no space). How to: http://www.dl-c.com/board/viewtopic.php?f=4&t=686

	-n[int]   NOISE_REDUC - This is the threshold of wavelet denoising - specify to use.
	  --> Use -n<number>. Defaults to no denoising. 150 tends to be a good setting; 350 starts to look strange.

	-g[0:4]   GAMMA - This is a modal gamma curve that is applied to the image. 0 is default.
	  --> Use -g<mode> (no space). 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.

	-S   SHALLOW - Specifying this option will create an 8-bit output instead of a 16-bit output.
	  --> It'll kind of ruin the point of RAW, though....


OPTIONS, COLOR:
	-w[0:3]   WHITE - This is a modal white balance setting. Defaults to 0. 1 doesn't always work very well.
	  --> Use -w<mode> (no space).
	  --> 0: Auto WB (Requires Python Deps). 1: Camera WB. 2: No Change.

	-F<path>   DARKFRAME - This is the path to the dark frame MLV.
	  --> This is a noise reduction technique: Record 5 sec w/lens cap on & same settings as footage.
	  --> Pass in that MLV file (must be MLV) as <path> to get noise reduction on all passed MLV files.

	-A[int]   WHITE_SPD - This is the amount of samples from which AWB will be calculated.
	  -->About this many frames, averaged over the course of the sequence, will be used to do AWB.

	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it.
	  --> Compatibility determined by ffmpeg (.cube is supported).
	  --> LUT cannot be applied to EXR sequences.
	  --> Path to LUT (no space between -l and path).


OPTIONS, DEPENDENCIES:
	-K   Debian Package Deps - Lists dependecies. Works with apt-get on Debian; should be similar elsewhere.
	  --> No operations will be done.
	  --> Example: sudo apt-get install $ (./convmlv -K)

	-Y   Python Deps - Lists Python dependencies. Works with pip.
	  --> No operations will be done. 
	  --> Example: sudo pip3 install $ (./convmlv -Y)


```
