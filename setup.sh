#!/bin/bash

# global variables
STDOUT=/dev/null
UBUNTU_VERSION=18.04

packages="$PWD/pkg/Ubuntu/$UBUNTU_VERSION/packages"

myinstall_pkgs()
{	
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

# bashrc
#if [ ! -s $HOME/.bashrc ]; then
#	echo "setting .bashrc ..."
#	cd $HOME
#	mv $HOME/.bashrc $HOME/.bashrc-`date +"%Y-%m-%d-%H-%M"`
#	ln -s $DROPBOX_ROOT/Documentos/Linux/bashrc .bashrc
#fi

# profile
#if [ ! -s $HOME/.profile ]; then 
#	echo "setting .pr;ofile ..."

#	cd $HOME
#	mv $HOME/.profile $HOME/.profile-`date +"%Y-%m-%d-%H-%M"`
#	ln -s $DROPBOX_ROOT/Documentos/Linux/profile .profile
#fi


myinstall_java()
{
	# java runtime environment
	if [ ! -f /etc/profile.d/jre.sh ]; then
		echo "setting java runtime environment ... "
		echo 'export PATH=/usr/local/java/bin:$PATH' | sudo tee /etc/profile.d/jre.sh
	fi

	# java firefox plugin
	if [ ! -s /usr/lib/mozilla/plugins/libnpjp2.so ]; then
		echo "setting firefox java plugin ... "
		cd /usr/lib/mozilla/plugins/
		sudo ln -s /usr/local/java/lib/amd64/libnpjp2.so
	fi
}

myinstall_php()
{
	# getting PHP version ...
	cd $HOME

	version=`php -v | egrep -o '^PHP[[:space:]][[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+'`
	version=`echo $version | egrep -o '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+'`

	PHPINI=/etc/php/7.0/apache2/php.ini

	wget https://raw.githubusercontent.com/php/php-src/php-$version/php.ini-development

	if [ $? -eq 0 ]; then
		sudo mv php.ini-development $PHPINI
	fi
}

myinstall_env()
{
	bash_aliases="$PWD/bash_aliases"
	scripts_folder="$PWD/scripts"
	packages="$PWD/pkg/Ubuntu/$UBUNTU_VERSION/packages"


	if [ ! -d "$scripts_folder" ]; then
		echo "scripts folder not found - aborting"		
	fi

	cp $HOME/.profile $HOME/.profile.`date +"%Y-%m-%d-%H-%M"`.tmp

	# bash_aliases
	if [ ! -s "$HOME/.bash_aliases" ]; then 

		if [ -f "$bash_aliases" ]; then 

			echo "setting .bash_aliases ..."
			cd $HOME
			mv $HOME/.bash_aliases $HOME/.bash_aliases-`date +"%Y-%m-%d-%H-%M"`
			ln -s "$bash_aliases" .bash_aliases

		else 
			echo "$bash_aliases file not found"
		fi

	else
		echo "symbolic link already created"
	fi

	# adding script folder to PATH
	if [ -d "$scripts_folder" ]; then
		echo -n "scripts folder found, adding to PATH ..."

		egrep -o -q "${scripts_folder}" ~/.profile
		if [ ! $? -eq 0 ]; then
			echo "export PATH='${scripts_folder}:\$PATH'" >> ~/.profile
			echo "added"
		else 
			echo "already added"
		fi		
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

myinstall_dpkg_hooks(){
	# restart web server everytime something is added or removed
	if [ -d /etc/dpkg/dpkg.cfg.d ]; then 
		echo "post-invoke=if test \"\$DPKG_HOOK_ACTION\" = install || test \$DPKG_HOOK_ACTION = remove ; then service apache2 restart; fi" | sudo tee /etc/dpkg/dpkg.cfg.d/restart-web-server

		echo "post-invoke=if test \"\$DPKG_HOOK_ACTION\" = install || test \$DPKG_HOOK_ACTION = remove ; then chmod a+rw /var/www/html; fi" | sudo tee /etc/dpkg/dpkg.cfg.d/rw-on-server-folder
	fi		
}

