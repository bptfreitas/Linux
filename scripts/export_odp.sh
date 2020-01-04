#!/bin/bash

DESTDIR=/var/www/html/SISOP/
#DESTDIR=$HOME/testeExportacao

if [ ! -d "$DESTDIR" ]; then 
	echo "$DESTDIR not found - Aborting"
	exit -1
fi

# convertendo aulas para pdf 
find . -name *.odp | xargs -I{} libreoffice --impress --convert-to pdf --outdir Aulas-PDF {} 

zip -r Aulas-PPC.zip Aulas-PDF/

[ -d "$DESTDIR/Aulas-PDF/" ] && rm -rf "$DESTDIR/Aulas-PDF/"

mv Aulas-PDF/ $DESTDIR/.
mv Aulas-PPC.zip $DESTDIR/.

# convertendo listas para pdf 
find . -name SISOP-Exercicios*.odt | xargs -I{} libreoffice --writer --convert-to pdf --outdir Listas-PDF {}

zip -r Listas-SISOP.zip Listas-PDF/

[ -d "$DESTDIR/Listas-PDF/" ] && rm -rf "$DESTDIR/Listas-PDF/"

mv Listas-PDF/ $DESTDIR/.
mv Listas-PPC.zip $DESTDIR/.

# copiando exemplos 
for d in $(find . -type d -maxdepth 1); do
	cd $d;

	if [ -d "Exemplos" ]; then 
		echo $d
	fi

	cd ..
done
