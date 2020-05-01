#!/bin/bash

debug=1
type=aluno

[ $debug -eq 1 ] && sudo iptables -F 

######################################
# setting firewall for internet only #
######################################
if [ $type == "internet" ]; then

    sudo iptables -P INPUT DROP
    sudo iptables -P OUTPUT DROP

    # DNS
    sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

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
    sudo iptables -A INPUT -p udp --dport 80 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 80 -j ACCEPT

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
    sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 443 -j ACCEPT

    if [ $debug -eq 1 ]; then 
        sudo iptables -t raw -A PREROUTING -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 443 -j TRACE
        sudo iptables -t raw -A INPUT -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A INPUT -p udp --dport 443 -j TRACE
        sudo iptables -t raw -A OUTPUT -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A OUTPUT -p udp --dport 443 -j TRACE
    fi

    exit
fi # fim - firewall de internet


#################################################
# setting firewall for internet use by students #
#################################################
if [ "$type" == "aluno" ]; then 
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    
    sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

    sudo iptables -A OUTPUT -d www.cefet-rj.br -j ACCEPT
    sudo iptables -A OUTPUT -d eadfriburgo.cefet-rj.br -j ACCEPT

    sudo iptables -P OUTPUT DROP
fi

sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

[ $debug -eq 1 ] && sudo iptables -L

