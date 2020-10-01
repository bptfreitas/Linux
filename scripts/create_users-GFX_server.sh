#!/bin/bash
if [[ "`egrep 'anaredes' /etc/passwd`" == "" ]]; then
	sudo adduser --disabled-password --gecos anaredes
	echo 'anaredes:abcd' | sudo chpasswd
fi

if [[ "`egrep 'bobredes' /etc/passwd`" == "" ]]; then
	sudo adduser --disabled-password --gecos bobredes
	echo 'bobredes:4321' | sudo chpasswd
fi

if [[ "`egrep 'sonyablade' /etc/passwd`" == "" ]]; then
	sudo adduser --disabled-password --gecos sonyablade
	echo 'sonyablade:123' | sudo chpasswd
fi

if [[ "`egrep 'johnnycage' /etc/passwd`" == "" ]]; then
	sudo adduser --disabled-password --gecos johnnycage
	echo 'johnnycage:123' | sudo chpasswd
fi

if [[ "`egrep 'cassiecage' /etc/passwd`" == "" ]]; then
	sudo adduser --disabled-password --gecos cassiecage
	echo 'cassiecage:123' | sudo chpasswd
fi

