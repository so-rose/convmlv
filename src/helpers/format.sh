#!/bin/bash

#desc: Text formatting functions.

bold() {
	echo -e "\033[1m${1}\033[0m"
}

selected() {
	echo -e "$(bold "\033[32m${1}\033[0m")"
}

error() {
	echo -e "$(bold "\033[31m${1}\033[0m")"
}

formArg() {
	#usage: formArg item selection
	#desc: Formats ARG values prettily; param can be "selected" or "deselected".
	#return: Formatted path.
	local item="$1"
	local selection="$2"
	
	local itemBase=$(basename $item)
	local itemExt=".${itemBase##*.}" #Dot must be in here.
	if [[ "${itemExt}" == ".${itemBase}" ]]; then itemExt=""; fi #This means the input is a folder, which has no extension.
	
	local itemDir=$(dirname "$item")
	
	if [[ $selection == "selected" ]]; then
		echo -e "${itemDir}/$(selected "${itemBase%.*}")${itemExt}"
	elif [[ $selection == "deselected" ]]; then
		echo -e "${itemDir}/$(bold ${itemBase%.*})${itemExt}"
	fi
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
