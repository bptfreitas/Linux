#!/bin/bash

> saidas.log
> notas.log

root="`pwd`"

for work in $(find . -maxdepth 1 -type d); do

    cd "$root"

    cd "$work"

    #name="${work##*-}"
    name="$work"

    echo -e "NAME: $name"

   if  [[ -f ../corrigir.sh ]]; then
   	echo "Copying custom corrigir.sh ..."
   	cp ../corrigir.sh .
   fi
    
    if [[ -f ../.grade_student.sh ]]; then
         echo "Copying custom .grade_student.sh ..." 
         cp ../.grade_student.sh .
   fi
   
   if [[ -f ../.Dockerfile ]]; then
         echo "Copying custom .Dockerfile ..." 
         cp ../.Dockerfile .
   fi

    chmod +x ./corrigir.sh

    ./corrigir.sh $name 1> saida.log 2>&1

    tail -1 saida.log > /tmp/nota.tmp
    echo "$name" > /tmp/nome.tmp

    paste /tmp/nome.tmp /tmp/nota.tmp >> ../notas.log
    
    echo -e "`cat /tmp/nota.tmp`\n"

    cd ..

done
