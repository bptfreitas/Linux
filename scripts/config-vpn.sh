#!/bin/bash 

LOG=/dev/stdout 

opt="$1"

case $opt in

start)
	timeout=1
	while :; do
		windscribe connect # >> $LOG
		windscribe status | grep -q CONNECTED
		if [ $? -eq 0 ]; then
			echo "`date +%c`: windscribe connected" 2>&1 # >> $LOG 
			break
		else
			sleep ${timeout}
			timeout=$(( timeout * 2 ))

			if [ ${timeout} -gt 32 ]; then 
				echo "`date +%c`: too many retries. Aborting" 2>&1 # >> $LOG
				exit -1
			else 
				echo "`date +%c`: waiting ${timeout}s before retry..." 2>&1 # >> $LOG
			fi
		fi
	done
	;;

stop)
	echo "Finishing service" 2>&1 
	windscribe disconnect
	sudo iptables -F OUTPUT
	sudo iptables -P OUTPUT ACCEPT 
	;;

*)
 	echo "Invalid option: \"$opt\"" 2>&1
 	exit -1
 	;;
esac



