#!/bin/bash

POSITIONAL=()

FORCE_REMOVE=0 # empties directory if it already exists
COPY_FOLDERS=0 # copy selected folder structures
COMPRESS=0 # compresses directory with converted pdfs
EXT=odp # chooses which libreoffice extention to convert to pdf
LOG=/dev/null # default log file

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		# folder to save converted pdfs
        --outdir|-o)
        DESTDIR="$2"
        shift # past argument
        shift # past value
        ;;

		# folder to search for files to convert
        --srcdir|-i)
        SRCDIR="$2"
        shift # past argument
        shift # past value
        ;;

		--force|-f)
		FORCE_REMOVE=1
		shift
		;;

		# select what extension to convert
		--ext|-e)
		EXT=$2
		shift # past argument
		shift # past value
		;;

		# compress pdf folder after extraction
		--zip|-z)
		COMPRESS=1
		shift
		;;

		# copy folder structure
		--dir|-d)
		COPY_FOLDERS=1
		FOLDER=$2
		shift # past argument
		shift # past value
		;;

		# unknown option
        *)    
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

################################
# Processing script parameters #
################################

# checking SRCDIR
if [ ! -d "${SRCDIR}" ]; then
	echo "${SRCDIR} not a directory - aborting"
	exit
fi

echo "SRCDIR: ${SRCDIR}"

# checking DESTDIR
if [ "${DESTDIR}" == "" ]; then 
	echo "${DESTDIR} not set - aborting"
	exit -1
else
	if [ ! -d "${DESTDIR}" ]; then

		# directory does not exist - creating it
		echo "Creating $DESTDIR ..."
		mkdir -p "$DESTDIR" 2>&1 > ${LOG}
		if [ $? -ne 0 ]; then
			echo "Error creating \"$DESTDIR\" - aborting"
			exit
		fi
	else

		# directory exists
		if [ `ls "${DESTDIR}" | wc -l` -ne 0 ]; then

			# directory exists and is not empty, check if it is marked to be removed
			echo -n "Directory ${DESTDIR} not empty"

			if [ $FORCE_REMOVE -eq 1 ]; then
				echo "- erasing old contents"
				rm -rf "${DESTDIR}" 2>&1 > ${LOG}

				if [ $? -eq 0 ]; then 
					mkdir -p ${DESTDIR}
				else
					exit 1
				fi  
			else
				echo "- aborting"
				exit 1
			fi
		else
			echo "Directory ${DESTDIR} already exists and is empty"
		fi
	fi
fi

echo "DESTDIR: ${DESTDIR}"

# checking EXT
case ${EXT} in
	odp)
		program=impress
		;;

	odt)
		program=writer
		;;

	*)
		echo "Error: Invalid extension: $EXT. Aborting"
		exit
		;;
esac

echo -e "Extension to export: ${EXT}\nProgram: ${program}"

###################
# Starting script #
###################

pdfdir="`basename $SRCDIR`-PDF"

echo "Exporting to ${pdfdir}"

# converting to pdf 
find ${SRCDIR} -name *.${EXT} | \
	xargs -I{} libreoffice \
	--${program} \
	--convert-to pdf \
	--outdir "${pdfdir}" {} 2> ${LOG}

# compressing files to zip, if needed
if [ ${COMPRESS} -eq 1 ]; then 
	echo "Compressing ${pdfdir} folder ..."
	zip -r "${pdfdir}.zip" "${pdfdir}/" 2>&1 > ${LOG}
	mv "${pdfdir}.zip" "${DESTDIR}/."
fi

# moving to DESTDIR
mv "${pdfdir}" "${DESTDIR}/."

# copy selected folder structure to output dir
if [ ${COPY_FOLDERS} -eq 1 ]; then

	echo "Copying all \"${FOLDER}\" found inside \"${SRCDIR}\""

	for dir in $(find "${SRCDIR}" -maxdepth 1 -type d); do

		if [ -d "${dir}" ]; then 
			echo ${dir}
		fi

	done

fi
