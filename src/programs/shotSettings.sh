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

printFileSettings() {
	ARG="${FILE_ARGS_ARRAY[0]}"
	checkArg
	
	BASE="$(basename "$ARG")"
	EXT="${BASE##*.}"
	
	if [ $EXT == "MLV" ] || [ $EXT == "mlv" ]; then
		# Read the header for interesting settings :) .
		mlvSet
		
		echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m: ${ARG}\n"
		prntSet
	elif [ $EXT == "RAW" ] || [ $EXT == "raw" ]; then
		rawSet
		
		echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m\033[0m: ${ARG}\n"
		prntSet
	elif [ -d $ARG ]; then
		dngSet
		
		echo -e "\n\033[1m\033[0;32m\033[1mFile\033[0m\033[0m: ${ARG}\n"
		prntSet
	else
		echo -e "Cannot print settings from ${ARG}; it's not a valid file!"
	fi
}
