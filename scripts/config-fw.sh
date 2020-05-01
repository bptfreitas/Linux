#!/bin/bash

debug=1

[ $debug -eq 1 ] && sudo iptables -F 

sudo iptables -P OUTPUT DROP

# DNS
sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# HTTP
sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 80 -j ACCEPT

# HTTPS
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 443 -j ACCEPT

# conexoes feitas sao aceitas
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

[ $debug -eq 1 ] && sudo iptables -L

