#!/bin/bash

# scan
TEMP=`mktemp`
#echo $TEMP
sudo iwlist wlp2s0 scanning > $TEMP


index=0
for line in $(cat $TEMP | egrep -n 'Cell' | awk '{ print $1 }' | sed 's/://'); do
	limits[$index]=$line
	index=$((index+1))
done

#echo ${limits[@]}
limit=
limit=$((limit-2))

TEMP2=`mktemp`
echo "$TEMP2"
for index in $(seq 0 $((${#limits[@]}-2)) ); do
	linf=${limits[$index]}
	lsup=$((${limits[$((index+1))]}-1))

	cat $TEMP | head -n $lsup | tail -n $((lsup-linf)) > $TEMP2
	echo $((index+1))") Data from $linf to $lsup:"
	ESSID=`cat $TEMP2 | egrep "ESSID:" | sed 's/[[:space:]]*ESSID://'`
	echo "ESSID: $ESSID"
done



# WIRELESS ROUTER (NO PASSWORD OR WEP SECURITY ONLY)
# wconfig wlan0 essid NAME_OF_ACCESS_POINT

# WIRELESS ROUTER (WPA or WPA2 SECURITY)
# wpa_passphrase SSID PASSWORD > CONFIG_FILE
