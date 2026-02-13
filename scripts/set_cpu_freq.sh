#!/bin/bash

if [[ "$1" == "" ]]; then

	echo "Usage: $0 min-frequency max-frequency"
	exit 1	
fi

if [[ "$2" == "" ]]; then

	echo "Usage: $0 min-frequency max-frequency"
	exit 2
fi


sudo cpupower frequency-set --max 3500000 GHz

sudo cpupower frequency-set --min 800000 GHz


