#!/bin/bash

MY_IP=$1
FILE2XFER=$2

if [[ $MY_IP == "" ]] || [[ ! -f "$FILE2XFER" ]]; then
	echo "Usage: $0 [MACHINE IP ADDRESS] [FILE]"
	exit 1
else
	echo "Base IP: $MY_IP"
fi

if [[ $SSHPASS == "" ]]; then
	echo 'SSH $SSHPASS password env variable not detected'
	exit 2
fi

if [[ ! -e /tmp/ips ]]; then
	echo "Getting network IPs ..."
	nmap -p 22 --open $MY_IP -oG - | awk '/22\/open/{print $2}' > /tmp/ips
fi

if [[ $? -ne 0 ]]; then
    echo "Error getting IP's!"
    exit 1
fi

> ./ips_ok.txt 

for ip in $(cat /tmp/ips ); do 
    echo "IP: $ip"   

	#ssh -t labredes@$ip \
	#	-o StrictHostKeyChecking=accept-new \
    #"sudo mkdir /public ; sudo chmod a=rwx /public;"
    
    sshpass -e rsync -av --progress --ignore-existing \
		-e 'ssh -o StrictHostKeyChecking=accept-new' \
    	$FILE2XFER \
    	labredes@$ip:/public/.

	if [[ $? -eq 0 ]]; then

		echo "Connection ok, adding to local IP's"

		echo $ip >> ./ips_ok.txt

	fi		

done
