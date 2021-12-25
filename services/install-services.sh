#!/bin/bash

DEBUG=1
CONF_OUTPUT=0

action="$1"
service="$2"
space="$3"


case $action in
	install|uninstall)	
		;;
	*)
		echo "Invalid action: \"$action\" "
		exit -1
		;;
esac;

find . -name "$service";

if [[ $? -ne 0 ]]; then
	echo "[ERROR] Service '$service' not found"
	exit -1
fi

case $space in
	user|system)
		;;
	*)
		echo "[ERROR] Invalid space: \"$action\". Must be 'user' or 'system' "
		exit -1
		;;
esac;

#        *)    
#            POSITIONAL+=("$1") # save it in an array for later
#            shift # past argument
#            ;;

curdir=`pwd`
rootdir=`dirname ${curdir}`

echo "Root dir: ${rootdir}"

echo ">>> STAGE 1: Stopping and disabling '${service}' <<<"

sudo systemctl stop ${service}
sudo systemctl disable ${service}

systemctl --user stop ${service}
systemctl --user disable ${service}

sudo rm -f "/etc/systemd/user/${service}"
sudo rm -f "/etc/systemd/system/${service}"

echo ">>> STAGE 2: Installing \"${service}\" on \"${space}\" space <<< "

sed -e "s/SERVICES_FOLDER/${rootdir//\//\\\/}/g" ${service} > ./${service}.tmp

sudo mv ./${service}.tmp /etc/systemd/${space}/${service}

echo ">>> STAGE 3: Reloading daemons <<< "

sudo systemctl daemon-reload
systemctl --user daemon-reload

echo ">>> STAGE 4: Enabling service <<< "

case $space in

	user)
		systemctl --user enable ${service};
		;;

	system)
		sudo systemctl enable ${service};
		;;
	*)
		echo "Invalid space for installation. Must be 'system' or 'user'"
		;;
esac;