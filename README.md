# convmlv #

MLV to TIFF/ProRes and Proxy ProRes/H.264
=======
See [http://www.magiclantern.fm/forum/index.php?topic=16799.0](http://www.magiclantern.fm/forum/index.php?topic=16799.0) for more info.

Help page is below:

```text

Usage:
	./convmlv.sh [OPTIONS] mlv_files

INFO:
	A script allowing you to convert .MLV or .RAW files into TIFF + JPG (proxy) sequences and/or a Prores 4444 .mov,
	with an optional H.264 .mp4 preview. Many useful options are exposed.

DEPENDENCIES: *If you don't use a feature, you don't need the dependency!
	-mlv_dump: For DNG extraction from MLV. http://www.magiclantern.fm/forum/index.php?topic=7122.0
	-raw2dng: For DNG extraction from RAW. http://www.magiclantern.fm/forum/index.php?topic=5404.0
	-mlv2badpixels.sh: For bad pixel removal. https://bitbucket.org/daniel_fort/ml-focus-pixels/src
	-dcraw: For RAW development.
	-ffmpeg: For video creation.
	-ImageMagick: Used for making proxy sequence.
	-Python 3 + libs: Used for auto white balance.
	-exiftool + xxd: Used in mlv2badpixels.sh.

VERSION: 1.5.0

OPTIONS, BASIC:
	-v   version - Print out version string.
	-o<path>   OUTDIR - The path in which files will be placed (no space btwn -o and path).
	-M<path>   MLV_DUMP - The path to mlv_dump (no space btwn -M and path). Default is './mlv_dump'.
	-R<path>   RAW_DUMP - The path to raw2dng (no space btwn -M and path). Default is './raw2dng'.
	-y<path>   PYTHON - The path or command used to invoke Python. Defaults to python3.
	-B<path>   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'.


OPTIONS, OUTPUT:
	-i   IMAGE - Specify to create a TIFF sequence.

	-m   MOVIE - Specify to create a Prores4444 video.

	-f   FPS - Specify the FPS to create the movie at. Defaults to 24.

	-p[0:3]   PROXY - Specifies the proxy mode.
	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.

	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output.
	  --> Use -s<percentage>% (no space). 50% is default.

	-k   KEEP_DNGS - Specify if you want to keep the DNG files.
	  --> Besides testing, this makes the script a glorified mlv_dump...


OPTIONS, RAW DEVELOPMENT:
	-d[0:3]   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default.
	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.

	-H[0:9]   HIGHLIGHT_MODE - 3 to 9 does degrees of colored highlight reconstruction, 1 and 2 allow clipping.
	  --> Use -H<number> (no space). 0 is default.

	-b   BADPIXELS - Fix focus pixels issue using dfort's script.
	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src.
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

	-A[int]   WHITE_SPD - This is the speed of the auto white balance, causing quality loss. Defaults to 15.
	  --> For AWB, the script averages the entire sequence, skipping n frames each time. This value is n.

	-l<path>   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it.
	  --> Compatibility determined by ffmpeg (.cube is supported).
	  --> Path to LUT (no space between -l and path). Without specifying -l, no LUT will be applied.


OPTIONS, DEPENDENCIES:
	-K   Debian Package Deps - Lists dependecies. Works with apt-get on Debian; should be similar elsewhere.
	  --> No operations will be done.
	  --> Example: sudo apt-get install $ (./convmlv -K)

	-Y   Python Deps - Lists Python dependencies. Works with pip.
	  --> No operations will be done. 
	  --> Example: sudo pip3 install $ (./convmlv -Y)

```
