#!/bin/bash

prefix="$1"

for d in $( find . -maxdepth 1 -type d | sort ); do

	[[ ! -d "$d" ]] && continue
	
	[[ "$d" == "." ]] && continue
	
	[[ "$d" == ".." ]] && continue
	
	compressed_file="${prefix}`basename $d`.zip"
		
	echo "Compressing $d to $compressed_file ..."
	
	zip -r $compressed_file $d 

done
