#!/bin/bash

DEBUG=1

action=reinstall

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		--install)
			action="install"
			shift # past argument
			;;

        --uninstall)
            action="uninstall"
            shift # past argument
            ;; 

		# reinstall
        --reinstall)
            CONF_OUTPUT=1
            shift # past argument
            ;;

		# unknown option
        *)    
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

curdir=`pwd`
rootdir=`dirname ${curdir}`
services_lst=/tmp/services.lst

echo "Root dir: ${rootdir}"

sed -e 's/#.*//' services.conf > /tmp/services.conf.tmp

> ${services_lst}

for service_conf in $(cat /tmp/services.conf.tmp); do

	service=`echo "${service_conf}" | cut -f1 -d:`
	space=`echo "${service_conf}" | cut -f2 -d:`

	echo "${service}" >> /tmp/services.lst

	echo "Stopping and disabling '${service}' on '${space}' space... "

	[ "${space}" == "user" ] && opt_USER=--user || opt_USER=""
	[ "${space}" == "system" ] && opt_SUDO=sudo || opt_SUDO=""

	${opt_SUDO} systemctl ${opt_USER} stop ${service}
	${opt_SUDO} systemctl ${opt_USER} disable ${service};

	echo "Installing \"${service}\" on \"${space}\" space ... "

	sed -e "s/SERVICES_FOLDER/${rootdir//\//\\\/}/g" ${service} > /tmp/${service}.tmp

	case ${space} in
		system|user)
			sudo mv /tmp/${service}.tmp /etc/systemd/${space}/${service}
			;;

		*)
			echo "Error! invalid space for service installation: ${space}"
			;;
	esac
done

echo "Reloading daemons ..."

sudo systemctl daemon-reload
systemctl --user daemon-reload

for service_conf in $(cat /tmp/services.conf.tmp); do
	service=`echo "${service_conf}" | cut -f1 -d:`
	space=`echo "${service_conf}" | cut -f2 -d:`

	echo "Enabling ${service} ... "]

	[ "${space}" == "user" ] && opt_USER=--user || opt_USER=""
	[ "${space}" == "system" ] && opt_SUDO=sudo || opt_SUDO=""

	${opt_SUDO} sudo systemctl ${opt_USER} enable ${service};
done

for service_conf in $(cat /tmp/services.conf.tmp); do
	service=`echo "${service_conf}" | cut -f1 -d:`
	space=`echo "${service_conf}" | cut -f2 -d:`

	echo "Starting ${service} ... "

	[ "${space}" == "user" ] && opt_USER=--user || opt_USER=""
	[ "${space}" == "system" ] && opt_SUDO=sudo || opt_SUDO=""	

	${opt_SUDO} systemctl ${opt_USER} start ${service};
done

rm ${services_lst}
rm /tmp/services.conf.tmp

# if [ ! -f "$PWD/git-sync.service" ]; then
# 	echo "git-sync.service not found - aborting"
# 	exit
# fi

# if [ ! -f "$PWD/git-sync.py" ]; then
# 	echo "git-sync.py not found - aborting"
# 	exit
# fi

# if [ ! -f "$PWD/git-repositories" ]; then
# 	echo "git-repositories not found - aborting"
# 	exit
# fi

# if [ -L /etc/systemd/system/git-sync.service ]; then
# 	unlink /etc/systemd/system/git-sync.service
# fi
# if [ -L /usr/local/bin/git-sync.py ]; then
# 	unlink /usr/local/bin/git-sync.py
# fi
# if [ -L $HOME/.git-repositories ]; then
# 	unlink $HOME/.git-repositories
# fi

# ln -s $PWD/git-sync.service /etc/systemd/system/git-sync.service

# ln -s $PWD/git-sync.py /usr/local/bin/git-sync.py

# chmod +x /usr/local/bin/git-sync.py

# ln -s $PWD/git-repositories $HOME/.git-repositories
