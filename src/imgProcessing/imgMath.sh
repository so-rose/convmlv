#!/bin/bash

#desc: Math for bash regarding image operations. So that we don't have to hop over to python!

normToOne() {
	wBal=$1
	
	max=0.0
	for mult in $wBal; do
		if [ $(echo " $mult > $max" | bc) -eq 1 ]; then
			max=$mult
		fi
	done
	
	for mult in $wBal; do
		echo -e "$(echo "scale=6; x=${mult} / ${max}; if(x<1) print 0; x" | bc -l) \c" #BC is bae.
	done
}

getGreen() {
	wBal=$1
	
	i=0
	for mult in $wBal; do
		if [ $i -eq 1 ]; then
			echo -e "${mult}"
		fi
		let i++
	done
}
