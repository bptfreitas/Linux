#!/bin/bash

## DESTDIR=/var/www/html/SISOP/
## DESTDIR=$HOME/testeExportacao

POSITIONAL=()

FORCE_REMOVE=0 # empties directory if it already exists
FORMAT=odp # chooses which libreoffice format to convert to pdf
LOG=/dev/null # default log file

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --outdir|-o)
        DESTDIR="$2"
        shift # past argument
        shift # past value
        ;;
        --srcdir|-i)
        SRCDIR="$2"
        shift # past argument
        shift # past value
        ;;
		-f)
		FORCE_REMOVE=1
		;;
		--format)
		FORMAT=$2
		shift
		;;
        ##--default)
        ##DEFAULT=YES
        ##shift # past argument
        ##;;
        *)    # unknown option
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
	if [ ! -d "$DESTDIR" ]; then 
		#directory does not exist - creating it

		echo "creating $DESTDIR ..."
		mkdir -p "$DESTDIR" 2>&1 > ${LOG}
		if [ $? -ne 0 ]; then
			echo "error creating \"$DESTDIR\""
			exit
		fi
	else
		# directory exists
	
		if [ `ls "${DESTDIR}" | wc -l` -ne 0 ]; then
			# directory exists and is not empty, check if it is marked to be removed

			if [ $FORCE_REMOVE -eq 1 ]; then
				echo "Emptying ${DESTDIR} ..."
				rm -rf "${DESTDIR}/*" 2>&1 > ${LOG}
			else
				echo "Directory ${DESTDIR} not empty - aborting"
				exit
			fi
		else 
			echo "Directory ${DESTDIR} already exists, not empty"
		fi
	fi
fi

echo "DESTDIR: ${DESTDIR}"

# checking FORMAT

case $FORMAT in
	odp)
		program=impress
		;;

	odt)
		program=writer
		;;

	*)
		echo "Error: Invalid extension: $FORMAT. Aborting"
		exit
		;;
esac

echo -e "Format to export: ${FORMAT}.\nProgram: ${program}"

###################
# Starting script #
###################

pdfdir="`basename $SRCDIR`-PDF"

echo "Exporting to ${pdfdir}"

# converting to pdf 
find ${SRCDIR} -name *.${FORMAT} | xargs -I{} libreoffice --${program} --convert-to pdf --outdir "${pdfdir}" {} 2> ${LOG}

# moving to DESTDIR
mv "${pdfdir}" "${DESTDIR}/."

## zip -r Aulas-PPC.zip Aulas-PDF/

## [ -d "$DESTDIR/Aulas-PDF/" ] && rm -rf "$DESTDIR/Aulas-PDF/"

## mv Aulas-PDF/ $DESTDIR/.
## mv Aulas-PPC.zip $DESTDIR/.

# convertendo listas para pdf 
## find . -name SISOP-Exercicios*.odt | xargs -I{} libreoffice --writer --convert-to pdf --outdir Listas-PDF {}


if [ 1 -eq 0 ]; then 
	zip -r Listas-SISOP.zip Listas-PDF/
fi

## [ -d "$DESTDIR/Listas-PDF/" ] && rm -rf "$DESTDIR/Listas-PDF/"

## mv Listas-PDF/ $DESTDIR/.
## mv Listas-PPC.zip $DESTDIR/.

# # copiando exemplos 
# for d in $(find . -type d -maxdepth 1); do
# 	cd $d;

# 	if [ -d "Exemplos" ]; then 
# 		echo $d
# 	fi

# 	cd ..
# done
