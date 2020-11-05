#!/bin/bash

DEV=1

if [[ $DEV -eq 1 ]]; then
    BASEDIR="tests/file-sorter"
    OUTDIR="testing/file-sorter"
    CMD='cp '
else

    CMD='mv '
fi

if [[ ! -d "$BASEDIR" ]]; then
    echo "[ERROR] Directory to search for files doesn't exist"
    exit 
fi

if [[ ! -d "$DESTDIR" ]]; then
    echo "[ERROR] Directory to search for files doesn't exist"
    exit 
fi



for file in $(ls $BASEDIR); do

    full_filename=$BASEDIR/$file
    
    
    year=`stat -c "%y" $full_filename | egrep -o -m 1 '[[:digit:]]{4,4}\-' | egrep -o '[[:digit:]]*'`
    month=`stat -c "%y" $full_filename | egrep -o -m 1 '\-[[:digit:]]{2,2}\-' | egrep -o '[[:digit:]]*'`    
    day=`stat -c "%y" $full_filename | egrep -o -m 1 '\-[[:digit:]]{2,2}' | head -2 | tail -1 | egrep -o '[[:digit:]]*'`

    folder_to_move="$DESTDIR/$year/$month/$day"

    echo "Moving $full_filename to '$folder_to_move' ... "

    if [[ ! -d "${folder_to_move}" ]]; then
        mkdir -p "${folder_to_move}"
    fi

    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Couldn't create folder '${folder_to_move}' (code $?)"
        exit -1
    fi

    $CMD "$full_filename" "$folder_to_move/."

done