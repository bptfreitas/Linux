#!/bin/bash

DEBUG=1

if [ ! -f "$PWD/git-sync.service" ]; then
	echo "git-sync.service not found - aborting"
	exit
fi

if [ ! -f "$PWD/git-sync.py" ]; then
	echo "git-sync.py not found - aborting"
	exit
fi

if [ ! -f "$PWD/git-repositories" ]; then
	echo "git-repositories not found - aborting"
	exit
fi

if [ -L /etc/systemd/system/git-sync.service ]; then
	unlink /etc/systemd/system/git-sync.service
fi
if [ -L /usr/local/bin/git-sync.py ]; then
	unlink /usr/local/bin/git-sync.py
fi
if [ -L $HOME/.git-repositories ]; then
	unlink $HOME/.git-repositories
fi

ln -s $PWD/git-sync.service /etc/systemd/system/git-sync.service

ln -s $PWD/git-sync.py /usr/local/bin/git-sync.py

chmod +x /usr/local/bin/git-sync.py

ln -s $PWD/git-repositories $HOME/.git-repositories
