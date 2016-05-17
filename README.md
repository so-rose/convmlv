# convmlv #

MLV/RAW/DNG to Image/Movie and Proxy
=======
See [http://www.magiclantern.fm/forum/index.php?topic=16799.0](http://www.magiclantern.fm/forum/index.php?topic=16799.0) for more info.

**Use the pdf found in the source, under docs->docs.pdf.**

Help page is below:

```text

Usage:
	./convmlv.sh [OPTIONS] mlv_files
	
INFO:
	A script allowing you to convert .MLV, .RAW, or a folder with a DNG sequence into a sequence/movie with optional proxies. Images
	are auto compressed. Many useful options are exposed, including formats (EXR by default).
	
VERSION: 1.8.2
	
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
	
	-m   MOVIE - Specify to create a Prores4444 video.
	
	-p[0:3]   PROXY - Specifies the proxy mode. 0 is default.
	  --> 0: No proxies. 1: H.264 proxy. 2: JPG proxy sequence. 3: Both.
	  --> JPG proxy won't be developed w/o -i. H.264 proxy will be developed no matter what, if specified.
	
	-s[0%:100%]   PROXY_SCALE - the size, in %, of the proxy output.
	  --> Use -s<percentage>% (no space). 50% is default.
	
	-k   KEEP_DNGS - Specify if you want to keep the DNG files.
	  --> If you run convmlv on the dng_<name> folder, you will reuse those DNGs - no need to redevelop!
	  
	-E<range>   FRAME_RANGE - Specify to process only this frame range.
	  --> Use s and e appropriately to specify start and end.
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
	-w[0:2]   WHITE - This is a modal white balance setting. Defaults to 1.
	  --> Use -w<mode> (no space).
	  --> 0: Auto WB (Requires Python Deps). 1: Camera WB. 2: No Change.
	  
	-L   WHITE_SCALE - Specify to allow channels to clip as a result of any white balance.
	  --> Information loss occurs in certain situations.
	  
	-t[int]   SATPOINT - Specify the 14-bit saturation point of your camera.
	  --> Lower if -H1 yields purple highlights. Must be correct for highlight reconstruction.
	  --> Determine using the max value of 'dcraw -D -j -4 -T'
	
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
```
