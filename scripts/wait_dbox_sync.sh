#!/bin/bash

time=5
inc=5

match="Indexando|Baixando|Enviando|Atualizando|Iniciando"

while [ "`sudo -u bruno dropbox status | egrep -o $match`" != "" ]; do
	sleep $time
	echo "Slept $time seconds"
	time=`echo $time+$inc|bc`
done;
	
shutdown -P now
