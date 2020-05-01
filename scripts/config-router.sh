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

echo "checking dhcpd daemon ... "
if [ "`which dhcpd`" == "" ]; then 
    echo "dhcpd daemon not found. Aborting. "
    exit
fi

sudo cp /etc/dhcpd/dhcpd.conf /root/dhcpd.conf.bk``

echo "
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
     option routers 192.168.200.100; #Este é o gateway padrão (neste caso).
     option broadcast-address 192.168.200.255; #Essa linha é o endereço de broadcast (neste caso).

    #Aqui você coloca os servidores DNS de terceiros ou seu DNS próprio configurado no BIND. Nesse caso coloquei o DNS do Google.
     option domain-name-servers 8.8.8.8; 
     option domain-name-servers 8.8.4.4;
}
" > /etc/dhcpd/dhcpd.conf


echo "checking leases file ... "
if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then 
    echo "dhcpd daemon not found. Aborting. "
    exit 
else
    sudo -u dhcpd chmod a+w /var/lib/dhcp/dhcpd.leases
fi

sudo -u dhcpd dhcpd

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE
sudo iptables -A FORWARD -i ${LAN} -j ACCEPT

sudo ifconfig ${WAN} down
sudo ifconfig ${WAN} down

sudo ifconfig ${LAN} up
sudo ifconfig ${LAN} up
