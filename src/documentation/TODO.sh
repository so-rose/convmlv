#!/bin/bash

#desc: Kinda standalone TODO list.

less -R << EOF

TODO:

PLANNING:
	Except for openlut integration, CM fixes, and the last throes of Mac compatibility, I consider convmlv feature-complete. As in, only bug fixes and error checking.
	New developments, like special ffmpeg filters, or new techniques from the ML world, may change that. But that\'s nothing compared to the 2400 lines this pushes at the moment!
	Any further effort is better focused on compatibility, bug fixes, error checking, more bug fixes, and finally a GUI app described in FUTURE.


TOP PRIORITY
--> Fix Color Management; -o 5 is broken. Use -o 0 or -o 1, supplemented by current paradigm of Rec709 -> Whatever LUTs, instead of XYZ -> Whatever LUTs.
--> MLVFS backend - run the mlvfs command, passing whatever options it supports, then rewrite ARG. Give an option to choose mlv_dump or mlvfs, and an option for a custom path to mlvfs.
*Consider using dcraw for darkframing, through the -K option. Requires a develop from MLV, then a convert to raw PGM, first.
--> Calibration frame program & library - place in $HOME/.local/convmlv, perhaps.
--> New program: Install dependencies.

HIGH PRIORITY
--> Integrate openlut for 1D LUTs. 3D LUTs would only be used for gamut transforms, not gamut/gamma.
--> More error checking.
--> Test Mac compatibility with a *working* (with 10.7) mlv_dump...
--> Documentation: Videos.

MEDIUM PRIORITY
--> Integrate openlut for gamut ops. Matrices would replace standard 3D LUTs altogether, and openlut would handle 3D LUTs.

LOW
--> Stats for .RAW files.


FUTURE
--> A GUI app, running libraw variants, which has a CLI backend, but can also output a convmlv config file.
    --> convmlv will always have more features - bash makes certain nasty things like ffmpeg filters available, as opposed to the \"code it yourself\" of true image array processing...
    --> But, a GUI is usable by the average non-nerd!! You know, the users of ML.


BUG: Relative OUTDIR makes baxpixel generation fail if ./mlv2badpixels.sh doesn\'t exist. Should be fixed on all platforms.
BIG BUG: Color Management is oversaturated, destructively so.
--> See Nasty Hacks Part 1 - 3. FML :O.


EOF
