mkDarkframe() {
	echo -e "\n\033[1m\033[0;32m\033[1mAveraging Darkframe File\033[0m: ${ARG}"
	$MLV_DUMP -o $DARK_OUT ${FILE_ARGS_ARRAY[0]} 2>/dev/null 1>/dev/null
	echo -e "\n\033[1m\033[1mWrote Darkframe File\033[0m: ${DARK_OUT}\n"
}
