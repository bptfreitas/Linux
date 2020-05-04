#!/bin/bash

debug=0
WITH_VPN=0

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		# with vpn discards OUTPUT filter
        --with-vpn)
        WITH_VPN=1
        shift # past argument
        ;;

		# unknown option
        *)    
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done

sudo iptables -F INPUT
sudo iptables -F FORWARD
[ $WITH_VPN -eq 0 ] && sudo iptables -F OUTPUT

# temporary firewall permissions
sudo iptables -P INPUT ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -P OUTPUT ACCEPT

# allow outgoing ICMP
# sudo iptables -A INPUT -p icmp -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -I OUTPUT 1 -p icmp -j ACCEPT

# allow DNS
sudo iptables -A INPUT -p tcp --sport 53 --dport 53 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p tcp --sport 53 --dport 53 -j ACCEPT

sudo iptables -A INPUT -p udp --sport 53 --dport 53 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p udp --sport 53 --dport 53 -j ACCEPT

if [ $debug -eq 1 ]; then 
    sudo iptables -t raw -A PREROUTING -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 53 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 53 -j TRACE    
    sudo iptables -t raw -A OUTPUT -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 53 -j TRACE
fi

# HTTP
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

sudo iptables -A INPUT -p udp --dport 80 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p udp --dport 80 -j ACCEPT

if [ $debug -eq 1 ]; then 
    sudo iptables -t raw -A PREROUTING -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 80 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 80 -j TRACE    
    sudo iptables -t raw -A OUTPUT -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 80 -j TRACE
fi

# HTTPS
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p udp --dport 443 -j ACCEPT

sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

if [ $debug -eq 1 ]; then 
    sudo iptables -t raw -A PREROUTING -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 443 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 443 -j TRACE
    sudo iptables -t raw -A OUTPUT -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 443 -j TRACE
fi

# default policy is DROP to all
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
[ $WITH_VPN -eq 0 ] && sudo iptables -P OUTPUT DROP

sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
[ $WITH_VPN -eq 0 ] && sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
## sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# send REJECT answers for attempted connections on INPUT and FORWARD chains
sudo iptables -A INPUT -j REJECT --reject-with tcp-reset
sudo iptables -A FORWARD -j REJECT --reject-with tcp-reset

sudo iptables -L

