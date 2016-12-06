bold() {
	echo -e "\033[1m${1}\033[0m"
}

cVal() {
	#usage: cVal value
	#desc: Formats config file values, as bolded grey.
	#return: Formatted value.
	
	echo -e "\033[1m\033[37m${1}\033[0m"
}

bVal() {
	#usage: bVal value
	#desc: Formats running (not related to development) options, as bolded green.
	#return: Formatted value.
	
	echo -e "\033[1m\033[32m${1}\033[0m"
}

head() {
	#usage: cVal value
	#desc: Formats help page header values, as bold.
	#return: Formatted value.
	
	echo -e "\033[1m${1}\033[0m"
}

iVal() {
	#usage: iVal value
	#desc: Formats important config values, as bolded yellow.
	#return: Formatted value.
	
	echo -e "\033[1m\033[33m${1}\033[0m"
}
