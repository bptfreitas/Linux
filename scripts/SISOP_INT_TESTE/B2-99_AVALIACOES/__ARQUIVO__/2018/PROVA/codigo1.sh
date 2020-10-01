#!/bin/bash

x=$1

if [ -d "$x" ]; then
    cd $x
    for y in $(find . -type f); do
        sudo cp $y $y.bk
        sudo chown bruno:bruno $y
        sudo chmod a-rwx $y
        sudo chmod g+r $y
        sudo chmod u+rwx $y
    done
else
    echo "Erro"
fi