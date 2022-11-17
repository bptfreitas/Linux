#!/bin/bash


env | grep -q "$INSTALLED_PKGS"

if [[ $? -ne 0 ]]; then 
	echo "[ERROR] $INSTALLED_PKGS env variable not set" > /dev/stdeer
	exit -1
fi

HISTORY_DIR=`dirname $INSTALLED_PKGS`/history
HISTORY=$HISTORY_DIR/packages-`date +"%Y-%m-%d__%H-%M-%S"`

actionlist="update|upgrade|dist-upgrade|dselect-upgrade|install|remove|purge|source|build-dep|check|download|clean|autoclean|autoremove|indextargets"

cmdline=$@

mkdir -p $HISTORY_DIR

/usr/bin/apt-get -q=2 --dry-run $cmdline || exit

params=""
action=""

echo "$1" | egrep -q "$actionlist"
while [ $? -ne 0 ]; do
	params="$params $1"
	shift
	echo "$actionlist" | egrep -ne "$1"
done

action=$1
shift

echo "command: $action"
echo "parameters: $params"
echo "packages: $@"

while [ "$1" != "" ]; do
	case $action in
		install)
			grep -q "^$1\$" $INSTALLED_PKGS
			if [ $? -ne 0 ]; then
				tmp=`mktemp`

				echo "Package $1 is not on the list. Adding it ..."

				echo "$1" > $tmp
				cat $INSTALLED_PKGS $tmp | sort > /tmp/new
				cp $INSTALLED_PKGS $HISTORY
				mv /tmp/new $INSTALLED_PKGS

				cd `dirname "$INSTALLED_PKGS"`
				git commit -m "Updating package list `date +"%Y-%m-%d__%H-%M-%S"`" `basename "$INSTALLED_PKGS"`
				git push origin master
			else
				echo "Package $1 is already on the list."
			fi
			;;

		remove)
			grep -q "^$1\$" $INSTALLED_PKGS
			if [ $? -eq 0 ]; then
				tmp=`mktemp`

				echo "Package $1 is on the list. Removing it ..."				

				awk "\$1 != \"$1\"" $INSTALLED_PKGS > /tmp/new
				cp $INSTALLED_PKGS $HISTORY
				mv /tmp/new $INSTALLED_PKGS

				cd `dirname "$INSTALLED_PKGS"`
				git commit -m "Updating package list `date +"%Y-%m-%d__%H-%M-%S"`" `basename "$INSTALLED_PKGS"`
				git push origin master

			else
				echo "Package $1 is already not on the list."
			fi
			;;
	esac

	shift
done

sudo /usr/bin/apt-get $cmdline || exit
