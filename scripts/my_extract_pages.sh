#!/bin/bash

file=$1
shift
first="$1"
shift
last="$1"

if [[ ! -f "$file" ]]; then
	echo "Usage: $0 file.pdf first_page [last_page]"
	exit 1
fi

echo "$first" | grep -Eqw '[0-9]+'
if [[ $? -ne 0 ]]; then
	echo "'$first' is not a number!"
	echo "Usage: $0 file.pdf first_page [last_page]"
	exit 1
fi

if [[ "$last" == "" ]]; then
	echo 'Setting $last = $first'
	last=$first
else
	echo "$last" | grep -Eqw '[0-9]+'
	if [[ $? -ne 0 ]]; then
		echo "'$last' is not a number!"
		echo "Usage: $0 file.pdf first_page [last_page]"
		exit 1		
	fi	
fi

gs -dNOPAUSE \
	-dQUIET \
	-dBATCH \
	-sOutputFile=extracted.pdf \
	-dFirstPage=$first \
	-dLastPage=$last \
	-sDEVICE=pdfwrite "$file"
