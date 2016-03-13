# convmlv #

MLV to TIFF/ProRes and Proxy ProRes/H.264
=======
See [http://www.magiclantern.fm/forum/index.php?action=post;topic=16799.0;last_msg=163719](Link URL) for more info.

Help page is below:

```<br>

Usage:
	./convmlv.sh [OPTIONS] mlv_files

INFO:
	A script allowing you to convert .MLV files into TIFF + JPG (proxy) sequences and/or a Prores 4444 .mov,
	with an optional H.264 .mp4 preview. Many useful options are exposed.

DEPENDENCIES:
	-mlv_dump: For MLV --> DNG.
	-dcraw: For DNG --> TIFF.
	-ffmpeg: For .mov/mp4 creation.
	-mlv2badpixels.sh: For badpixels removal.
	-convert: Part of ImageMagick.

VERSION: 1.3.0

OPTIONS:
	-V   Version - Print out version string.
	-o   OUTDIR - The path in which files will be placed (no space btwn -o and path).

	-M   MLV_DUMP - The path to mlv_dump (no space btwn -M and path). Default is './mlv_dump'.

	-B   MLV_BP - The path to mlv2badpixels.sh (by dfort). Default is './mlv2badpixels.sh'.

	-H[0-9]   HIGHLIGHT_MODE - 3 to 9 does degrees of highlight reconstruction, 1 and 2 don't. 0 is default.
	  --> Use -H<number> (no space).

	-s[00-99]%   PROXY_SCALE - the size, in %, of the proxy output.
	  --> Use -s<double-digit number>% (no space). 50% is default.

	-m   HQ_MOV - Use to create a Prores 4444 file.

	-p   LQ_MOV - Use to create a low quality H.264 mp4 from the proxies.

	-D   DELETE_IMGS - Use to delete not only TMP, but also the TIF and proxy sequences.
	  --> Useful if all you want are video files.

	-d   DEMO_MODE - DCraw demosaicing mode. Higher modes are slower. 1 is default.
	  --> Use -d<mode> (no space). 0: Bilinear. 1: VNG (default). 2: PPG. 3: AHD.

	-K   Package Deps - Lists dependecies. Works with apt-get.
	  --> No operations will be done. Also, you must provide mlv_dump.

	-g   GAMMA - This is a modal gamma curve that is applied to the image. 0 is default.
	  --> Use -g<mode> (no space). 0: Linear. 1: 2.2 (Adobe RGB). 2: 1.8 (ProPhoto RGB). 3: sRGB. 4: BT.709.

	-P   DEPTH - Specifying this option will create an 8-bit output instead of a 16-bit output.
	  --> It'll kind of ruin the point of RAW, though....

	-W   WHITE - This is a modal white balance setting. Defaults to 2; 1 doesn't always work very well.
	  --> Use -W<mode> (no space). 0: Auto WB (BROKEN). 1: Camera WB (If retrievable). 2: No WB Processing.

	-l   LUT - This is a path to the 3D LUT. Specify the path to the LUT to use it.
	  --> Compatibility determined by ffmpeg (.cube is supported).
	  --> Path to LUT (no space between -l and path). Without specifying -l, no LUT will be applied.

	-n   NOISE_REDUC - This is the threshold of wavelet denoising - specify to use.
	  --> Use -n<number>. Defaults to no denoising. 150 tends to be a good setting; 350 starts to look strange.

	-b   BADPIXELS - Fix focus pixels issue using dfort's script.
	  --> His file can be found at https://bitbucket.org/daniel_fort/ml-focus-pixels/src.
```
