#!/bin/bash

old="$1"

new="$2"

if [[ $old == "" ]]; then

	echo "Usage: $0 old-date new-date"
	exit 1
fi 


for f in $( find . -type f); do

	echo "Old file: $f"

	newfile="`echo "$f" | sed 's/'$1'/'$2'/'`"
	
	echo "---> New file: $newfile"
	
	mv $f $newfile



done
