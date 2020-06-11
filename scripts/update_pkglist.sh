#!/bin/bash

DEBUG=0

if [[ $DEBUG -eq 1 ]]; then 
    pkglist=/tmp/pkglist
elif [[ $DEBUG -eq 0 ]]; then
    echo "$INSTALLED_PKGS"
    env | grep -q INSTALLED_PKGS

    if [[ $? -ne 0 ]]; then 
        echo "ERROR: \$INSTALLED_PKGS env var is not set"
        exit -1
    fi

    pkglist="$INSTALLED_PKGS"
fi

action="$1"

case $action in
    # with vpn discards OUTPUT filter
    install|-i)
        shift # past argument
        #shift # past value
        echo -n "Checking sanity ... "
        pkgs=$*
        apt-get --dry-run install ${pkgs[@]} 2>&1 > /dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "ok.\nUpdating ${pkglist} ... "
        else 
            echo "ERROR: \"$pkgs\" is not a valid package list"
			exit -1
        fi

        for pkg in ${pkgs}; do
            echo ${pkg} >> "${pkglist}"
        done

        sort "${pkglist}" | uniq > /tmp/pkglist.tmp

		if [[ `diff -q ${pkglist} /tmp/pkglist.tmp` -eq 0 ]]; then 
			mv /tmp/pkglist.tmp "${pkglist}"

			echo -n "Commiting new package list ..."
			cur_dir="$PWD"
			cd `dirname ${pkglist}`
			git commit -m "Packages update: `date +%c`" `basename ${pkglist}` 2>&1 > /dev/null
			[ $? -eq 0 ] && echo "ok" || echo "FAIL"
			cd "${cur_dir}"
		else
			echo "Nothing changed"
		fi

		echo "Contents of ${pkglist}:"
		column -x ${pkglist}
        ;;

    remove|-r)


        ;;

    # consider all unknown options to be packages
    *)
        echo "Invalid action: \"$1\"" # save it in an array for later
        exit
        ;;
esac
