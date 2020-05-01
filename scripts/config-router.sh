#!/bin/bash


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

sudo cp /etc/dhcpd/dhcpd.conf /root/dhcpd.conf.bk

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

#####################################
# configuring network configuration #
#####################################

echo "
network:
   ethernets:
      enp0s3:
         dhcp4: true
      enp0s8:
         addresses: [192.168.200.1/24]
         dhcp4: false
   version: 2
" | sudo tee /etc/netplan/50-cloud-init.yaml

sudo netplan apply

echo "checking leases file ... "
if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then 
    echo "dhcpd daemon not found. Aborting. "
    exit 
#else
#    sudo -u dhcpd chmod a+w /var/lib/dhcp/dhcpd.leases
fi

sudo -u dhcpd dhcpd

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F 

###################################
# configuring router capabilities #
###################################

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE
sudo iptables -A FORWARD -i ${LAN} -j ACCEPT

###########################################
# configuring basic firewall for students #
###########################################

sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

sudo iptables -A OUTPUT -o ${WAN} -d www.cefet-rj.br -j ACCEPT
sudo iptables -A OUTPUT -o ${WAN} -d eadfriburgo.cefet-rj.br -j ACCEPT

sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

sudo iptables -P OUTPUT DROP

sudo ifconfig ${WAN} down
sudo ifconfig ${LAN} down

sudo ifconfig ${WAN} up
sudo ifconfig ${LAN} up
