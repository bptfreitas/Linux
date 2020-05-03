#!/bin/bash

LAN=enp0s8
WAN=enp0s3

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --lan)
        LAN="$2"
        shift # past argument
        shift # past value
        ;;
        --wan)
        WAN="$2"
        shift # past argument
        shift # past value
        ;;
        --default)
        DEFAULT=YES
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

echo "WAN interface: ${WAN}"
echo "LAN interface: ${LAN}"

if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi

############################
# configuring dhcpd daemon #
############################

echo "checking dhcpd daemon ... "
if [ "`which dhcpd`" == "" ]; then 
    echo "dhcpd daemon not found. Aborting. "
    exit
fi

sudo cp /etc/dhcp/dhcpd.conf /root/dhcpd.conf-`date +%Y-%m-%d_%H-%M-%S`.bk

echo '
# dhcpd.conf
#
# Configuration file for ISC dhcpd (see 'man dhcpd.conf')
#
authoritative;
#Domínio configurado no BIND
#option domain-name \"seudominio.com.br\";

default-lease-time 600; #controla o tempo de renovação do IP
max-lease-time 7200; #determina o tempo que cada máquina pode usar um determinado IP. 

subnet 192.168.200.0 netmask 255.255.255.0 {
     range 192.168.200.101 192.168.200.200;  #faixa de IPs que o cliente pode usar.
     option routers 192.168.200.1; #Este é o gateway padrão (neste caso).
     option broadcast-address 192.168.200.255; #Essa linha é o endereço de broadcast (neste caso).

    #Aqui você coloca os servidores DNS de terceiros ou seu DNS próprio configurado no BIND. Nesse caso coloquei o DNS do Google.
    option domain-name-servers 8.8.8.8; 
    option domain-name-servers 8.8.4.4;
}
' | sudo tee /etc/dhcp/dhcpd.conf

echo "checking leases file ... "
if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then 
    echo "dhcpd daemon leases file not found. Aborting. "
    exit
fi

sudo chown root:root /var/lib/dhcp/dhcpd.leases
sudo chmod +w /var/lib/dhcp/dhcpd.leases
sudo killall dhcpd
sudo dhcpd


################################
# configuring network settings #
################################

echo "
network:
   ethernets:
      ${WAN}:
         dhcp4: true
      ${LAN}:
         addresses: [192.168.200.1/24]
         dhcp4: false
   version: 2
" | sudo tee /etc/netplan/50-cloud-init.yaml

sudo netplan apply

###################################
# configuring router capabilities #
###################################

# flushing all firewall status
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE

# allow DNS from LAN
sudo iptables -A FORWARD -i ${LAN} -p udp --dport 53 -j ACCEPT
sudo iptables -A FORWARD -i ${LAN} -p tcp --dport 53 -j ACCEPT

# allow selected sites from LAN
sudo iptables -A FORWARD -i ${LAN} -d www.cefet-rj.br -j ACCEPT
sudo iptables -A FORWARD -i ${LAN} -d eadfriburgo.cefet-rj.br -j ACCEPT

if [ -f allowed-sites ]; then 
	for site in $(cat allowed-sites); do
		sudo iptables -A FORWARD -i ${LAN} -d ${site} -j ACCEPT
	done
fi

sudo iptables -A FORWARD -i ${LAN} -j REJECT

###########################################
# configuring basic firewall for students #
###########################################

# allow ICMP

## sudo iptables -A OUTPUT -p icmp -j ACCEPT

# allow DNS

sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

# allow HTTP/HTTPS

sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 80 -j ACCEPT

sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT


# accepts already established connections and related new connections on all chains

sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

## sudo iptables -t filter -A OUTPUT -j REJECT --reject-with tcp-reset
## sudo iptables -t filter -A INPUT -j REJECT --reject-with tcp-reset

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

# restarts interfaces 

sudo ifconfig ${WAN} down
sudo ifconfig ${LAN} down

sudo ifconfig ${WAN} up
sudo ifconfig ${LAN} up
