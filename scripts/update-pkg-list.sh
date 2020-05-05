#!/bin/bash

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		# with vpn discards OUTPUT filter
        install)
        shift # past argument
        #shift # past value
        ;;

		# consider all unknown options to be packages
        *)
        pkgs+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done

apt install 