#!/bin/bash 

LOG=~/.windscribe-connect.log

while [ 1 -eq 1 ]; do
	windscribe connect >> $LOG
	windscribe status | grep -q CONNECTED
	if [ $? -eq 0 ]; then 
		echo "`date +%c`: windscribe connected" >> $LOG
		break
	else 
		timeout = $(( timeout * 2))

		if [ ${timeout} -gt 64 ]; then 
			echo "`date +%c`: timeout excceded" >> $LOG
			exit -1
		else 
			echo "`date +%c`: waiting ${timeout}s before retry..." >> $LOG
			sleep ${timeout}
		fi				
	fi
done 



