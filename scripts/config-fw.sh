#!/bin/bash

debug=0
CONF_OUTPUT=0

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		# with vpn discards OUTPUT filter
        --output)
        CONF_OUTPUT=1
        shift # past argument
        ;;

		# unknown option
        *)    
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done


# temporary firewall permissions
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT

#######################
# INPUT configuration #
#######################

sudo iptables -F INPUT

# allow outgoing ICMP
# sudo iptables -A INPUT -p icmp -j ACCEPT

# allow DNS
sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

# allow incoming HTTP
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 80 -j ACCEPT

# allow incoming HTTPS
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT

# allow related and established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# send REJECT answers for all other connections
sudo iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
sudo iptables -A INPUT -p udp -j REJECT --reject-with icmp-host-unreachable

# default policy is DROP to all
sudo iptables -P INPUT DROP

if [ $debug -eq 1 ]; then 
    sudo iptables -t raw -A PREROUTING -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 53 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 53 -j TRACE    
    sudo iptables -t raw -A OUTPUT -p tcp --dport 53 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 53 -j TRACE

    sudo iptables -t raw -A PREROUTING -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 80 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 80 -j TRACE    
    sudo iptables -t raw -A OUTPUT -p tcp --dport 80 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 80 -j TRACE

    sudo iptables -t raw -A PREROUTING -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A PREROUTING -p udp --dport 443 -j TRACE
    sudo iptables -t raw -A INPUT -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A INPUT -p udp --dport 443 -j TRACE
    sudo iptables -t raw -A OUTPUT -p tcp --dport 443 -j TRACE
    sudo iptables -t raw -A OUTPUT -p udp --dport 443 -j TRACE
fi

#########################
# FORWARD configuration #
#########################

sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 
sudo iptables -A FORWARD -p tcp -j REJECT --reject-with tcp-reset
sudo iptables -A FORWARD -p udp -j REJECT --reject-with icmp-host-unreachable

sudo iptables -P FORWARD DROP

########################
# OUTPUT configuration #
########################

if [ ${CONF_OUTPUT} -eq 1 ]; then
    # temporary ACCEPT policy
    sudo iptables -F OUTPUT
    sudo iptables -P OUTPUT ACCEPT

    # allow outgoing DNS
    sudo iptables -A OUTPUT -p udp --sport 53 --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --sport 53 --dport 53 -j ACCEPT

    # allow outgoing ICMP
    sudo iptables -I OUTPUT 1 -p icmp -j ACCEPT

    # allow outgoing HTTP
    sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 80 -j ACCEPT

    # allow outgoing HTTPS
    sudo iptables -A OUTPUT -p udp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

    # allow related and estabilished connections
    sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # default policy is DROP
    sudo iptables -P OUTPUT DROP    
fi

sudo iptables -L

