#!/bin/bash

sudo chmod a+w /var/lib/dhcp/dhcpd.leases

sudo dhcpd


echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
sudo iptables -A FORWARD -i enp0s8 -j ACCEPT

sudo ifconfig enp0s3 down
sudo ifconfig enp0s8 down

sudo ifconfig enp0s3 up
sudo ifconfig enp0s8 up
