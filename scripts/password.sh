#!/bin/bash

FILENAME=senhas.txt
PASSWORD_ROOT=~/Documentos/Other
TMP_DIR=/dev/shm

regexp="[[:digit:]]{2,2}\:[[:digit:]]{2,2}\:[[:digit:]]{2,2}"

cp $PASSWORD_ROOT/$FILENAME.gpg ${TMP_DIR}/$FILENAME.gpg

gpg ${TMP_DIR}/$FILENAME.gpg

if [ $? -eq 0 ]; then
	lastMod=`stat -c %y ${TMP_DIR}/$FILENAME | egrep -o "$regexp"`
	echo "last modification: $lastMod"

	gedit /tmp/${FILENAME} &&
	newMod=`stat -c %y ${TMP_DIR}/$FILENAME | egrep -o "$regexp"` &&

	echo "new modification: $newMod" &&\

	if [ "$newMod" != "$lastMod" ]; then \
		gpg -c ${TMP_DIR}/${FILENAME/.gpg/}
		cp ${TMP_DIR}/$FILENAME.gpg $PASSWORD_ROOT/.
	fi &&\

	rm -f ${TMP_DIR}/$FILENAME ${TMP_DIR}/$FILENAME.gpg
fi


