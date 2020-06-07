#!/bin/bash 

LOG=/dev/stdout 

if [ -f ${HOME}/.vpn-locations ]; then
	shuf ${HOME}/.vpn-locations > ~/.vpn-locations.session
	
	cur_loc=1
	N_loc=`wc -l ${HOME}/.vpn-locations | awk '{ print $1 }'`
else 
	rm -f ~/.vpn-locations.session
fi

opt="$1"

case $opt in

start)
	timeout=1
	while :; do
		if [ -f ${HOME}/.vpn-locations.session ]; then
			location=`sed -n "${cur_loc}{p;q}" ${HOME}/.vpn-locations.session`
			cur_loc=$(( (cur_loc + 1) % N_loc ))
			
			echo "Location: ${location}"
		else 
			location=""
		fi
		windscribe connect ${location}
		windscribe status | grep -q CONNECTED
		if [ $? -eq 0 ]; then
			echo "`date +%c`: windscribe connected" 2>&1 # >> $LOG

			## allow only HTTPS outgoing traffic to pass through VPN 
			## sudo iptables -I OUTPUT 1 -p tcp --dport 443 -j ACCEPT
			## sudo iptables -I OUTPUT 2 -p udp --dport 443 -j ACCEPT
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
	rm -f ${HOME}/.vpn-locations.session 
	;;

*)
 	echo "Invalid option: \"$opt\"" 2>&1
 	exit -1
 	;;
esac



