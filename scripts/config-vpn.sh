#!/bin/bash 

VPN_LOCATIONS=/root/vpn-locations
VPN_SESSION=${VPN_LOCATIONS}.session

if [[ -f "${VPN_LOCATIONS}" ]]; then
	echo "Setting VPN session file: ${VPN_SESSION} ... "
	shuf "${VPN_LOCATIONS}" > ${VPN_SESSION}
	
	cur_loc=1
	N_loc=`wc -l "${VPN_SESSION}" | awk '{ print $1 }'`
else 
	echo "[INFO] No locations file found: ${VPN_LOCATIONS} "
	rm -f ${VPN_SESSION}
fi

opt="$1"

case $opt in

	start)
		timeout=2
		while :; do
			if [[ -f "${VPN_SESSION}" ]]; then
				location=`sed -n "${cur_loc}{p;q}" "${VPN_SESSION}"`
				cur_loc=$(( (cur_loc + 1) % N_loc ))
				
				echo "Location: ${location}"
			else 
				location=""
				echo "No location set"
			fi
			windscribe connect ${location}
			windscribe status | grep -q CONNECTED
			if [[ $? -eq 0 ]]; then
				echo "`date +%c`: windscribe connected"

				#msteams open
				#sites open	
				config-fw.sh open msteams -1 3
				config-fw.sh open sites -1 3

				## allow only HTTPS outgoing traffic to pass through VPN 
				## sudo iptables -I OUTPUT 1 -p tcp --dport 443 -j ACCEPT
				## sudo iptables -I OUTPUT 2 -p udp --dport 443 -j ACCEPT
				break
			else
				sleep ${timeout}
				timeout=$(( timeout * 2 ))

				if [[ ${timeout} -gt 32 ]]; then 
					echo "`date +%c`: too many retries. Aborting" 2>&1 # >> $LOG
					exit -1
				else 
					echo "`date +%c`: waiting ${timeout}s before retry..." 2>&1 # >> $LOG
				fi
			fi
		done
		;;

	stop)
		echo "Finishing VPN service"
		windscribe disconnect
		sudo iptables -F OUTPUT
		sudo iptables -P OUTPUT ACCEPT
		rm -f "${VPN_LOCATIONS}.session"
		;;

	*)
		echo "Invalid option: \"$opt\""
		exit -1
		;;
esac