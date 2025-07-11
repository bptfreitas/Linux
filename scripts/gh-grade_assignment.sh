#!/bin/bash

> saidas.log
> notas.log

root="`pwd`"

for work in $(find . -maxdepth 1 -type d); do

    cd "$root"

    cd "$work"

    name="${work##*-}"

    echo -e "NAME: $name"

    cp ../corrigir.sh .

    chmod +x ./corrigir.sh

    ./corrigir.sh $name | tee -a ../saidas.log

    tail -1 ../saidas.log > /tmp/nota.tmp
    echo "$name" > /tmp/nome.tmp

    paste /tmp/nome.tmp /tmp/nota.tmp >> ../notas.log

    cd ..

done