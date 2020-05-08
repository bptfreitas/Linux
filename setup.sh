#!/bin/bash

# global variables
STDOUT=/dev/null

myinstall_pkgs()
{	
	ubuntu_version=`lsb_release -a | grep 'Release' | egrep -o '[[:digit:]]+\.[[:digit:]]+'`
	packages="$PWD/pkg/Ubuntu/${ubuntu_version}/packages"

	# distro upgrade
	echo "Atualizando a lista de pacotes ... "
	sudo apt-get -q update

	echo "Fazendo upgrade ... "
	sudo apt-get -y upgrade

	# package's installation
	if [ ! -f $packages ]; then
		echo "error: $packages not found"
		return 1
	fi
	

	if [ -f "$packages" ]; then 
		ok_pkgs=`mktemp`
		error_pkgs=missingpackages-`date +"%Y-%m-%d_%H-%M"`.txt
		for pkg in $(cat "$packages"); do
			echo -n "Checando $pkg ...";
		 	apt-get install -q -s -y $pkg > /dev/null
			if [ $? -eq 0 ]; then 
				echo "ok";
				echo "$pkg" >> $ok_pkgs ;

			else 
				echo "ERROR";
				echo "$pkg" >> $error_pkgs ;
			fi
		done

		sudo apt-get install -y `cat $ok_pkgs`
	fi
}

myinstall_dropbox()
{
	# dropbox
	cat /etc/sysctl.conf | egrep -q fs.inotify.max_user_watches > $STDOUT
	if [ "$?" != "0" ]; then
		echo "setting Dropbox max file's watch"
		echo fs.inotify.max_user_watches=100000 | sudo tee -a /etc/sysctl.conf; 
		sudo sysctl -p
	fi
}

myinstall_java()
{
	# java runtime environment
	if [ ! -f /etc/profile.d/jre.sh ]; then
		echo "setting java runtime environment ... "
		echo 'export PATH=/usr/local/java/bin:$PATH' | sudo tee /etc/profile.d/jre.sh
	fi
}

myinstall_php()
{
	# getting PHP version ...
	version=`php -v | egrep -o '^PHP[[:space:]][[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+'`
	version=`echo $version | egrep -o '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+'`

	# PHP configuration files
	PHPINI=/etc/php/${version}/apache2/php.ini
	PHPINI_DEVEL=/usr/lib/php/${version}/php.ini-development

	echo "php.ini path: ${PHPINI}"
	echo "php-development.ini path: ${PHPINI_DEVEL}"

	if [ -f "${PHPINI} ] && [ -f "${PHPINI_DEVEL} ]; then
		echo "Copying PHP development configuration ..."
		sudo cp ${PHPINI_DEVEL} ${PHPINI}

		echo "Restarting server ..."
		sudo systemctl restart apache2.service
	else
		echo "Error! Configuration files don't exist!"
	fi
}

myinstall_env()
{
	scripts_folder="$PWD/scripts"
	ubuntu_version=`lsb_release -a | grep 'Release' | egrep -o '[[:digit:]]+\.[[:digit:]]+'`
	packages="$PWD/pkg/Ubuntu/${ubuntu_version}/packages"

	cp $HOME/.profile $HOME/.profile.`date +"%Y-%m-%d-%H-%M"`.tmp

	# adding script folder to PATH
	if [ -d "${scripts_folder}" ]; then
		echo -n "scripts folder found, adding to PATH ..."

		egrep -o -q "${scripts_folder}" ~/.profile
		if [ ! $? -eq 0 ]; then
			echo "export PATH='${scripts_folder}:\$PATH'" >> ~/.profile
			echo "added"
		else 
			echo "already added"
		fi		
	else 
		echo "scripts folder not found - aborting"
	fi

	# adding custom env vars to profile
	grep -q 'INSTALLED_PKGS' $HOME/.profile
	if [ $? -ne 0 ]; then
		echo "adding global packages variable ..."
		echo "export INSTALLED_PKGS=\"$packages\"" >> ~/.profile
	else 
		echo "installed packages environmental var already set"
	fi		
}

