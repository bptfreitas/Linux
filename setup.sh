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

myinstall_webserver()
{
	if [ -f /etc/apache2/apache2.conf ]; then 

		echo "Stopping web-server ..."
		sudo systemctl stop apache2.service	

		echo "Backing up current configuration ... "
		cp /etc/apache2/apache2.conf ${HOME}/.apache2-`date '+%Y-%m-%d_%H-%M-%S'`.conf

		echo "Enabling security configurations..."
		

		echo "<Directory \"/srv/pub\">
			Options Indexes FollowSymLinks
			AllowOverride None
			Require all granted
			</Directory>" \
			| sudo tee /etc/apache2/sites-enabled/100-srv-pub.conf	

		echo "Alias \"/arquivos\" \"/srv/pub/arquivos\"" \
			| sudo tee /etc/apache2/sites-enabled/101-arquivos.conf

		echo "Alias \"/disciplinas\" \"/srv/pub/disciplinas\""\
			| sudo tee /etc/apache2/sites-enabled/102-disciplinas.conf

		## Require all granted 

		echo "Starting web-server ..."
		sudo systemctl start apache2.service
	else 
		echo "Web server not installed!"
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

myinstall_aliases()
{ 
	> ${HOME}/.bash_aliases
	
	echo "alias fw='while :; do clear; sudo iptables -vnL; sleep 3; done'" >> \
		${HOME}/.bash_aliases

	echo "alias fw-output='while :; do clear; sudo iptables OUTPUT -vnL; sleep 3; done'" >> \
		${HOME}/.bash_aliases

	echo "alias fw-input='while :; do clear; sudo iptables OUTPUT -vnL; sleep 3; done'" >> \
		${HOME}/.bash_aliases	
		
	echo "alias merge-pdfs='gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=combined_pdf_files.pdf -dBATCH'" >> \
		${HOME}/.bash_aliases
		
	echo "alias watch-freqs=\"watch -n 2 \"grep '^[c]pu MHz' /proc/cpuinfo"\"\" >> \
		${HOME}/.bash_aliases
			
}

myinstall_env()
{
	scripts_folder="$PWD/scripts"
	ubuntu_version=`lsb_release -a | grep 'Release' | egrep -o '[[:digit:]]+\.[[:digit:]]+'`
	packages="$PWD/pkg/Ubuntu/${ubuntu_version}/packages"

	cp $HOME/.profile $HOME/.profile.`date +"%Y-%m-%d-%H-%M"`.tmp

	# adding script folder to PATH
	if [[ -d "${scripts_folder}" ]]; then
		echo -n "scripts folder found, adding to PATH ..."

		egrep -o -q "${scripts_folder}" ~/.profile
		if [ ! $? -eq 0 ]; then
			echo "export PATH=\"${scripts_folder}:\$PATH\"" >> ~/.profile
			echo "added"
		else 
			echo "already added"
		fi		
	else 
		echo "scripts folder not found - aborting"
	fi

	# adding INSTALLED_PKGS env var to profile
	if [ -f "${packages}" ]; then
		grep -q 'INSTALLED_PKGS' $HOME/.profile
		if [ $? -ne 0 ]; then
			echo "adding global packages variable ..."
			echo "export INSTALLED_PKGS=\"$packages\"" >> ~/.profile
		else 
			echo "installed packages environment variable already set"
		fi
	else
		echo "Packages file ${packages} not found - aborting"
	fi

	# creates a folder to put custom latex
	mkdir -p ~/texmf/tex/latex 
}

myinstall(){
	echo "Starting environment setup ..."

	myinstall_pkgs

	myinstall_php

	myinstall_java

	myinstall_env

	myinstall_aliases
}

