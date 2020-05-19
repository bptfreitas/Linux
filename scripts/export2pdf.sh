#!/bin/bash

POSITIONAL=()

FILE_PREFIX="" # custom search file prefix 
EXPORT_FOLDER="" # custom folder name for export
FORCE_REMOVE=0 # empties directory if it already exists
UPDATE_ONLY=0 # exports only newer files
SORT=0

ZIP=0 # zips directory with converted pdfs
ZIP_NAME="" # custom zip prefix to file
REMOVE_AFTER_ZIP=0 # removes folder after compression

COPY_FOLDERS=0 # copy selected folder structures

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

		# select what extension to convert
		--ext|-e)
		EXT=$2
		shift # past argument
		shift # past value
		;;

		# force outdir removal if it exists
		--force|-f)
		FORCE_REMOVE=1
		shift
		;;

		--update-only|-u)
		UPDATE_ONLY=1
		shift
		;;		

		# file prefix to scan
		--file-prefix)
		FILE_PREFIX="$2"
		shift # past argument
		shift # past value
		;;

		# custom folder name
		--export-folder)
		EXPORT_FOLDER="$2"
		shift # past argument
		shift # past value
		;;		

		# compress pdf folder after conversion
		--zip)
		ZIP=1
		shift
		;;

		# custom zip name
		--zip-name)
		ZIP_NAME="$2"
		shift # past argument
		shift # past value
		;;

		# sort files
		--sort)
		SORT=1
		shift # past value
		;;		

		# copy folder structure instead of converting
		--dir)
		COPY_FOLDERS=1
		FOLDER=$2
		shift # past argument
		shift # past value
		;;

		# remove folder after comversion (used with zip)
		--no-folder)
		REMOVE_AFTER_ZIP=1
		shift #past argument
		shift #past value
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
				echo "- overwriting contents ... "
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

# checking if file prefix is set
[ "" != "${FILE_PREFIX}" ] &&\
	echo "File prefix to convert: ${FILE_PREFIX}"

# checking if export only newer files is set
if [ ${UPDATE_ONLY} -eq 1 ]; then
	find_update_cmd="-mtime 1"
	zip_update_cmd="u"
else
	find_update_cmd=""
	zip_update_cmd=""
fi

###################
# Starting script #
###################

echo

if [ "${EXPORT_FOLDER}" == "" ]; then 
	pdfdir="`basename $SRCDIR`-PDF"
else
	pdfdir="${EXPORT_FOLDER}"
fi

tmpdir="`mktemp -d`"
tmpfile="`mktemp`"

echo "Exporting to ${tmpdir} ..."

if [ ${SORT} -eq 1 ]; then
	tmpdir_sort="`mktemp -d`"
	all_files_list="`mktemp`"

	find ${SRCDIR} -name ${FILE_PREFIX}*.${EXT} \
		| sort > ${all_files_list}

	i=1
	for file_fullpath in `cat ${all_files_list}`; do

		filename=`basename ${file_fullpath}`

		index=`printf "%02d" ${i}`
		i=$(( i + 1 ))

		new_filename=`echo "${filename}" | sed -e "s/${FILE_PREFIX}/${FILE_PREFIX}-${index}/g"`		

		echo -e "Renaming '${filename}' to '${new_filename}'"

		cp --preserve ${file_fullpath} ${tmpdir_sort}/${new_filename}

		# new_filename=`echo "${filename}" | sed "s/${FILE_PREFIX}/${FILE_PREFIX}-${index}/g"`

		# echo -e "Novo nome: ${new_filename}\n"
	done

	SRCDIR="${tmpdir_sort}"
fi

find ${SRCDIR} ${find_update_cmd} -name ${FILE_PREFIX}*.${EXT} | \
	xargs -I{} libreoffice \
	--${program} \
	--convert-to pdf \
	--outdir "${tmpdir}" {} 2> ${LOG}

# compressing files to zip, if needed
if [ ${ZIP} -eq 1 ]; then 

	if [ "${ZIP_NAME}" == "" ]; then 
		zip_name="${pdfdir}.zip"
	else
		zip_name="${ZIP_NAME}.zip"
	fi

	echo "Compressing '${tmpdir}' folder to '${zip_name}' ..."

	zip -r${zip_update_cmd} "${zip_name}" "${tmpdir}/" 2>&1 > ${LOG}
	mv "${zip_name}" "${DESTDIR}/."

	# if [ ${REMOVE_AFTER_ZIP} -eq 1]; then

	# else

	# fi
fi

# moving files to DESTDIR
echo "Moving \"${tmpdir}\" to \"${DESTDIR}/${pdfdir}"
mv "${tmpdir}" "${DESTDIR}/${pdfdir}"

# copy selected folder structure to output dir
if [ ${COPY_FOLDERS} -eq 1 ]; then

	echo "Copying all \"${FOLDER}\" found inside \"${SRCDIR}\""

	for dir in $(find "${SRCDIR}" -maxdepth 1 -type d); do

		if [ -d "${dir}/${FOLDER}" ]; then 
			echo ${dir}
		fi

	done
fi
