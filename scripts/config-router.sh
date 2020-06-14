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

    if [[ "${LAN}" == "" ]]; then 
        echo "[ERROR] LAN interface not set: \"${LAN}\""
        exit -1
    else
        echo "LAN interface: ${LAN}"
    fi

    if [[ "${WAN}" == "" ]]; then 
        echo "[ERROR] LAN interface not set: \"${WAN}\""
        exit -1
    else
        echo "WAN interface: ${WAN}"
    fi

    if [[ -n $1 ]]; then
        echo "Last line of file specified as non-opt/last argument:"
        tail -1 "$1"
    fi

    if  [[ "`locate ifconfig`" == "" ]]; then 
        echo "net-tools not found - installing ..."
        sudo apt -y install net-tools
    fi

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
        option domain-name-servers 8.8.4.4;
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

    echo "network:" | sudo tee /etc/netplan/50-cloud-init.yaml
    echo "    ethernets:" | sudo tee -a /etc/netplan/50-cloud-init.yaml
    echo "        ${WAN}:" | sudo tee -a /etc/netplan/50-cloud-init.yaml
    echo "            dhcp4: true" | sudo tee -a /etc/netplan/50-cloud-init.yaml
    echo "        ${LAN}:" | sudo tee -a /etc/netplan/50-cloud-init.yaml
    echo "            addresses: [192.168.200.1/24]" | sudo tee -a /etc/netplan/50-cloud-init.yaml
    echo "            dhcp4: false" | sudo tee -a /etc/netplan/50-cloud-init.yaml

    sudo netplan apply

    ###################################
    # configuring router capabilities #
    ###################################

    # resetting configuration
    sudo iptables -F FORWARD
    sudo iptables -t nat -F POSTROUTING 
    sudo iptables -P FORWARD ACCEPT

    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
    sudo iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE

    # allow DNS from LAN to pass
    sudo iptables -A FORWARD -i ${LAN} -p udp --dport 53 -j ACCEPT
    sudo iptables -A FORWARD -i ${LAN} -p tcp --dport 53 -j ACCEPT

    # allow selected sites from LAN
    sudo iptables -A FORWARD -i ${LAN} -d www.google.com -j ACCEPT
    sudo iptables -A FORWARD -i ${LAN} -d www.cefet-rj.br -j ACCEPT
    sudo iptables -A FORWARD -i ${LAN} -d eadfriburgo.cefet-rj.br -j ACCEPT

    if [[ -f allowed-sites ]]; then 
        for site in $(cat allowed-sites); do
            sudo iptables -A FORWARD -i ${LAN} -d ${site} -j ACCEPT
        done
    fi

    # discards tcp connections with resets
    sudo iptables -A FORWARD -i ${LAN} -p tcp -j REJECT --reject-with tcp-reset

    # reject udp packets with host unreachable
    sudo iptables -A FORWARD -p udp -j REJECT --reject-with icmp-host-unreachable

    # drop anything else
    sudo iptables -P FORWARD DROP

    #########################################
    # configuring INPUT firewall for router #
    #########################################

    # discards ICMPs
    sudo iptables -A INPUT -p icmp -j REJECT --reject-with icmp-host-unreachable

    # drop broadcasts 
    sudo iptables -A INPUT -m addrtype --dst-type BROADCAST -j DROP

    # allow incoming HTTP
    sudo iptables -A INPUT -p tcp --sport 80 -j ACCEPT

    # allow incoming HTTPS
    sudo iptables -A INPUT -p tcp --sport 443 -j ACCEPT

    # accept established incoming connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # drop or reject everything else 
    sudo iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
    sudo iptables -A INPUT -p udp -j REJECT --reject-with icmp-host-unreachable

    # default policy is drop
    sudo iptables -P INPUT DROP

    ##########################################
    # configuring OUTPUT firewall for router #
    ##########################################

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
    sudo ifconfig ${LAN} down

    sudo ifconfig ${WAN} up
    sudo ifconfig ${LAN} up

    ;;

*)
    echo "Invalid option: ${option}"
    ;;

esac