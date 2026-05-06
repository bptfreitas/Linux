#!/bin/bash

file=$1

if [[ ! -f $file ]]; then
    echo "Invalid file"
    exit 1
fi

dd if=/dev/random of=/tmp/rand.out count=1 bs=10B

cat /tmp/rand | tee -a 