#!/bin/bash


DEBUG=1

if [[ $DEBUG -eq 1 ]]; then 
    LAN=enp0s8
    WAN=enp0s3
fi

option="$1"
shift

case $option in

setup)

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

    # resetting configuration
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT

    sudo iptables -F    

    if [[ "${LAN}" == "" ]]; then 
        echo "[ERROR] LAN interface not set: \"${LAN}\""
        exit -1
    else
        echo "LAN interface: ${LAN}"
    fi

    if [[ "${WAN}" == "" ]]; then 
        echo "[ERROR] WAN interface not set: \"${WAN}\""
        exit -1
    else
        echo "WAN interface: ${WAN}"
    fi

    if [[ -n $1 ]]; then
        echo "Last line of file specified as non-opt/last argument:"
        tail -1 "$1"
    fi

    if  [[ "`which ifconfig`" == "" ]]; then 
        echo "net-tools not found - installing ..."
        sudo apt -y install net-tools
    fi

    sudo apt -y install ssh

    ############################
    # configuring dhcpd daemon #
    ############################

    echo "checking dhcpd daemon ... "
    if [ "`which dhcpd`" == "" ]; then 
        echo "dhcpd daemon not found. Installing ..."
        sudo apt -y install isc-dhcp-server
    fi

    if [[ ! -f /etc/dhcp/dhcpd.conf ]]; then 
        echo "[ERROR] dhcp.conf file not found"
    fi

    sudo cp /etc/dhcp/dhcpd.conf /root/dhcpd.conf-`date +%Y-%m-%d_%H-%M-%S`.bk

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
        option routers 192.168.200.1; #Este é o gateway padrão (neste caso).
        option broadcast-address 192.168.200.255; #Essa linha é o endereço de broadcast (neste caso).

        #Aqui você coloca os servidores DNS de terceiros ou seu DNS próprio configurado no BIND. Nesse caso coloquei o DNS do Google.
        option domain-name-servers 8.8.8.8;
    }
    " | sudo tee /etc/dhcp/dhcpd.conf

    echo "checking leases file ... "
    if [ ! -f /var/lib/dhcp/dhcpd.leases ]; then 
        echo "dhcpd daemon leases file not found. Aborting. "
        exit
    fi

    sudo chown root:root /var/lib/dhcp/dhcpd.leases
    sudo chmod u+w /var/lib/dhcp/dhcpd.leases
    sudo killall dhcpd
    sudo dhcpd

    ################################
    # configuring network settings #
    ################################

    netplan_cfg=/etc/netplan/99-router.yaml

    sudo rm -f /etc/netplan/*

    echo "network:" | sudo tee ${netplan_cfg}
    echo "    ethernets:" | sudo tee -a ${netplan_cfg}
    echo "        ${WAN}:" | sudo tee -a ${netplan_cfg}
    echo "            dhcp4: true" | sudo tee -a ${netplan_cfg}
    echo "        ${LAN}:" | sudo tee -a ${netplan_cfg}
    echo "            addresses: [192.168.200.1/24]" | sudo tee -a ${netplan_cfg}
    echo "            dhcp4: false" | sudo tee -a ${netplan_cfg}

    sudo netplan apply

    ###################################
    # configuring router capabilities #
    ###################################

    # restarting WAN and LAN
    sudo ifconfig ${WAN} down
    sudo ifconfig ${WAN} up

    sudo ifconfig ${LAN} down
    sudo ifconfig ${LAN} up

    # foward DNS from LAN
    sudo iptables -A FORWARD -p udp --dport 53 -j ACCEPT

    # allow established and related connections
    sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

    # discards tcp connections with resets
    sudo iptables -A FORWARD -i ${LAN} -p tcp -j REJECT --reject-with tcp-reset

    # reject udp packets with host unreachable
    sudo iptables -A FORWARD -i ${LAN} -p udp -j REJECT --reject-with icmp-host-unreachable

    # allow forwarding in the kernel
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
    sudo iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE    

    #########################################
    # configuring INPUT firewall for router #
    #########################################

    # discards ICMPs
    sudo iptables -A INPUT -p icmp -j REJECT --reject-with icmp-host-unreachable

    # drop broadcasts 
    sudo iptables -A INPUT -m addrtype --dst-type BROADCAST -j DROP

    # allow SSH connections 
    sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # allow DNS
    sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

    # allow incoming HTTP
    sudo iptables -A INPUT -p tcp --sport 80 -j ACCEPT

    # allow incoming SSL/HTTPS
    sudo iptables -A INPUT -p tcp --sport 443 -j ACCEPT

    # accept established incoming connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # drop or reject everything else 
    sudo iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
    sudo iptables -A INPUT -p udp -j REJECT --reject-with icmp-host-unreachable

    ##########################################
    # configuring OUTPUT firewall for router #
    ##########################################

    # default policies
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT

    ########################################
    # creating a service to make it simple #
    ########################################

    # saving rules
    sudo iptables-save | sudo tee /root/router.rules

    sudo systemctl stop router.service
	sudo systemctl disable router.service

    serviceunit=/etc/systemd/system/router.service
    
    echo "[Unit]" | sudo tee ${serviceunit}
    echo "Description=Configures router startup" | sudo tee -a ${serviceunit}
    echo "After=network.target" | sudo tee -a ${serviceunit}
    echo "Requires=network.target" | sudo tee -a ${serviceunit}

    echo -ne "\n" | sudo tee -a ${serviceunit}

    echo "[Service]" | sudo tee -a ${serviceunit}
    echo "Type=oneshot" | sudo tee -a ${serviceunit}
    echo "RemainAfterExit=yes" | sudo tee -a ${serviceunit}
    echo "ExecStart=/sbin/iptables-restore /root/router.rules" | sudo tee -a ${serviceunit}
    echo "ExecStart=/bin/echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward" | sudo tee -a ${serviceunit}
    # ExecStartPost=SERVICES_FOLDER/scripts/config-fw.sh open msteams
    echo -ne "\n" | sudo tee -a ${serviceunit} 

    echo "[Install]" | sudo tee -a ${serviceunit}
    echo "WantedBy=multi-user.target" | sudo tee -a ${serviceunit}

    sudo systemctl daemon-reload
    sudo systemctl enable router.service

    # restarts interfaces 
    sudo ifconfig ${WAN} down
    sudo ifconfig ${WAN} up

    sudo ifconfig ${LAN} down
    sudo ifconfig ${LAN} up

    # allow forwarding of selected sites from LAN
    for site in $(sudo cat /root/allowed-sites); do
        echo "${site}"        
        sudo iptables -I FORWARD 2 -d ${site} -j ACCEPT
    done    
    ;;

stop)
    sudo iptables -F 
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT

    sudo systemctl stop router.service
    ;;


*)
    echo "Invalid option: ${option}"
    ;;

esac