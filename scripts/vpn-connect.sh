#!/bin/bash 

opt="$1"

case $opt in

start)
	LOG=/dev/stdout
	timeout=1
	while :; do
		windscribe connect # >> $LOG
		windscribe status | grep -q CONNECTED
		if [ $? -eq 0 ]; then
			echo "`date +%c`: windscribe connected" # >> $LOG
		else
			sleep ${timeout}
			timeout=$(( timeout * 2 ))

			if [ ${timeout} -gt 32 ]; then 
				echo "`date +%c`: too many retries. Aborting" # >> $LOG
				exit -1
			else 
				echo "`date +%c`: waiting ${timeout}s before retry..." # >> $LOG
			fi
		fi
	done
	;;

stop)
	echo "Finishing service"
	sudo windscribe disconnect
	sudo iptables -F OUTPUT
	sudo iptables -P OUTPUT ACCEPT 
	;;

*)
 	echo "Invalid option: \"$opt\""
 	exit -1
 	;;
esac



