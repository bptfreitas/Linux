#!/usr/bin/python

DIR2TEST=$1

for dir in $(ls); do
	if [ "$dir" != "$DIR2TEST" ]; 
	then
		tmpd=`mktemp -d`
		cp $dir/*.php $tmpd/.

		for src in $(ls $tmpd/*.php); do
			sed ''

		done;
	fi

done
