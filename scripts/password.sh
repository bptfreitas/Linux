#!/bin/bash

debug=1

if [ "`env | grep "PASSWORD_FILE"`" == "" ]; then
	echo "\$PASSWORD_FILE not set - Aborting"
	exit
fi

encfile=`basename $PASSWORD_FILE`
plainfile=`basename $encfile .gpg`
tmp_dir=/dev/shm

[ 1 -eq $debug ] && echo "encfile: $encfile"
[ 1 -eq $debug ] && echo "plainfile: $plainfile"

regexp="[[:digit:]]{2,2}\:[[:digit:]]{2,2}\:[[:digit:]]{2,2}"

cp $PASSWORD_FILE ${tmp_dir}/${encfile}

gpg ${tmp_dir}/${encfile}

if [ $? -eq 0 ]; then
	lastMod=`stat -c %y ${tmp_dir}/${plainfile} | egrep -o "$regexp"`
	echo "time of last modification: $lastMod"

	gedit ${tmp_dir}/${plainfile} &&
	newMod=`stat -c %y ${tmp_dir}/${plainfile} | egrep -o "$regexp"` &&

	echo "time of new modification: $newMod" &&\

	if [ "$newMod" != "$lastMod" ]; then \
		echo "encrypting file again ..."
		gpg -c ${tmp_dir}/${plainfile}
		cp ${tmp_dir}/${encfile} $PASSWORD_FILE
	fi &&\

	rm -f ${tmp_dir}/${encfile} ${tmp_dir}/${plainfile}
fi


