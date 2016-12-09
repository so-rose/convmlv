argOUTDIR() {
	val="$1"
	OUTDIR="$val"
	SETTINGS[path_output]="$val"
}

argBIN_PATH() {
	val="$1"
	BIN_PATH=="$val"
	SETTINGS[path_bin]=="$val"
}

argDCRAW() {
	val="$1"
	DCRAW="$val"
	SETTINGS[bin_dcraw]="$val"
}

argMLV_DUMP() {
	val="$1"
	MLV_DUMP="$val"
	SETTINGS[bin_mlvdump]="$val"
}

argRAW_DUMP() { 
	val="$1"
	RAW_DUMP="$val"
	SETTINGS[bin_rawdump]="$val"
}

argMLV_BP() { 
	val="$1"
	MLV_BP="$val"
}

argCR_HDR() { 
	val="$1"
	CR_HDR="$val"
}

argPYTHON() { 
	val="$1"
	PYTHON="$val"
}

argTHREADS() { 
	val="$1"
	THREADS="$val"
}

argIMAGE() { 
	IMAGES=true
}

argIMG_FMT() { 
	val="$1"
	case ${val} in
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
}

argMOVIE() { 
	MOVIE=true
}

argPROXY() { 
	val="$1"
	case ${val} in
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
}

argPROXY_SCALE() { 
	val="$1"
	PROXY_SCALE=val
	
	proxy_num=`echo "$PROXY_SCALE" | cut -d'%' -f 1`
	if [[ ! ( ($proxy_num -le 100 && $proxy_num -ge 5) && $proxy_num =~ ^-?[0-9]+$ ) ]];then
		invOption "Invalid Proxy Scale: ${PROXY_SCALE}"
	fi
}

argKEEP_RAWS() { 
	val="$1"
	KEEP_DNGS=true
}

argFRAME_RANGE() { 
	val="$1"
	RANGE_BASE="$val"
	isFR=false
}

argUNCOMP() { 
	isCOMPRESS=false
}

argDEMO_MODE() { 
	val="$1"
	DEMO_MODE="$val"
}

argHIGHLIGHT_MODE() { 
	val="$1"
	HIGHLIGHT_MODE="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

argOUTDIR() { 
	val="$1"
	OUTDIR="$val"
}

