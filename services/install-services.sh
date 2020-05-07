#!/bin/bash

DEBUG=1

curdir=`pwd`
rootdir=`dirname ${curdir}`
services_lst=/tmp/services.lst

echo "Root dir: ${rootdir}"

# sed 's/^#.*\\n$//g' services.conf

> ${services_lst}

for service_conf in $(cat services.conf); do

	service=`echo "${service_conf}" | cut -f1 -d:`
	space=`echo "${service_conf}" | cut -f2 -d:`

	echo "${service}" >> /tmp/services.lst

	echo "Stopping and disabling ${service} ... "

	sudo systemctl stop ${service}
	sudo systemctl disable ${service}

	echo "Installing \"${service}\" on \"${space}\" space ... "

	sed -e "s/SERVICES_FOLDER/${rootdir//\//\\\/}/g" ${service} > /tmp/${service}.tmp

	case ${space} in
		system)
			sudo mv /tmp/${service}.tmp /etc/systemd/${space}/${service}
			;;

		user)
			[ ! -d ${HOME}/.config/systemd/user ] && mkdir -p ${HOME}/.config/systemd/user
			mv /tmp/${service}.tmp ${HOME}/.config/systemd/user/${service}
			;;

		*)
			echo "Error! invalid space for service installation: ${space}"
			;;
	esac
done

sudo systemctl daemon-reload

for service in $(cat ${services_lst}); do
	echo "Enabling ${service} ... "
	sudo systemctl enable ${service}
done

for service in $(cat ${services_lst}); do
	echo "Starting ${service} ... "
	sudo systemctl start ${service}
done

rm ${services_lst}

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
