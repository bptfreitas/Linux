#!/bin/bash

DEBUG=0
CONF_OUTPUT=0
WITH_TUN=0

action="$1"
shift

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
		# configures an output filter as well
        --with-output)
            WITH_OUTPUT=1
            shift # past argument
            ;;

        --without-output)
            WITH_OUTPUT=0
            shift # past argument
            ;;            

        # allows selected incoming traffic from tunnels
        --with-tun)
            WITH_VPN=1
            shift # past argument
            ;;

        --without-tun)
            WITH_VPN=0
            shift # past argument
            ;;

        # applications with 
        open|close)
            ;;

		# unknown option
        *)    
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

case ${action} in

start)
    #######################
    # INPUT configuration #
    #######################

    # temporary firewall permissions and flushing old configuration
    sudo iptables -P INPUT ACCEPT
    sudo iptables -F INPUT

    # allow incoming ICMP only through tunnels
    if [ ${WITH_TUN} -eq 1 ]; then 
        sudo iptables -A INPUT -i tun+ -p icmp -j ACCEPT
    fi

    sudo iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
    
    # drop all broadcasts
    sudo iptables -A INPUT -m addrtype --dst-type BROADCAST -j DROP

    # reject all ICMP
    sudo iptables -A INPUT -p icmp -j REJECT --reject-with icmp-host-unreachable

    # allow MS Teams to go through the firewall

    # allow incoming DNS
    ## sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    ## sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

    # allow incoming traffic only through HTTPS / SSL 
    ## sudo iptables -A INPUT -p tcp --sport 443 --dport 443 -j ACCEPT
    ## sudo iptables -A INPUT -p udp --sport 443 --dport 443 -j ACCEPT
    
    # from HTTP 
    #sudo iptables -A INPUT -i tun+ -p tcp --sport 80 -j ACCEPT
    # from SSL
    #sudo iptables -A INPUT -i tun+ -p tcp --sport 443 -j ACCEPT
    # from proxmox
    #sudo iptables -A INPUT -i tun+ -p udp --sport 8006 -j ACCEPT

    # allow HTTP requests
    sudo iptables -A INPUT -p tcp --sport 80 -j ACCEPT
    # allow SSL requests
    sudo iptables -A INPUT -p tcp --sport 443 -j ACCEPT    

    # allow incoming TCP connection in 'related' and 'established' states
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # send REJECT answers for all other connections
    sudo iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
    sudo iptables -A INPUT -p udp -j REJECT --reject-with icmp-host-unreachable

    # default policy is DROP to all
    sudo iptables -P INPUT DROP

    #########################
    # FORWARD configuration #
    #########################

    sudo iptables -F FORWARD
    sudo iptables -P FORWARD ACCEPT

    ## sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 
    sudo iptables -A FORWARD -p tcp -j REJECT --reject-with tcp-reset
    sudo iptables -A FORWARD -p udp -j REJECT --reject-with icmp-host-unreachable

    sudo iptables -P FORWARD DROP

    ########################
    # OUTPUT configuration #
    ########################

    if [ ${WITH_OUTPUT} -eq 1 ]; then
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

        # allow related and established connections
        sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

        # default policy is DROP
        sudo iptables -P OUTPUT DROP 

    fi
    ;; # fim: action start

open)
    program=${POSITIONAL[0]}

    case $program in
        # proxmox virtualization tool
        proxmox)
            sudo iptables -I INPUT 5 -p tcp --sport 8006 -j ACCEPT

            sudo iptables -I OUTPUT 1 -p udp --dport 8006 -j ACCEPT
            sudo iptables -I OUTPUT 2 -p tcp --dport 8006 -j ACCEPT        
            ;; # end: open proxmox

        # SSH 
        ssh)
            sudo iptables -I INPUT 5 -p tcp --sport 22 --dport 22 -j ACCEPT
            sudo iptables -I INPUT 6 -p tcp --sport 22 --dport 22 -j ACCEPT

            sudo iptables -I OUTPUT 1 -p udp --sport 22 --dport 22 -j ACCEPT
            sudo iptables -I OUTPUT 2 -p tcp --sport 22 --dport 22 -j ACCEPT        
            ;; # end: open proxmox            

        # Microsoft Teams
        msteams)
            sudo iptables -I INPUT 4 -p udp --sport 3478:3481 -j ACCEPT
            sudo iptables -I INPUT 5 -s 13.107.64.0/18 -j ACCEPT
            sudo iptables -I INPUT 6 -s 52.112.0.0/14 -j ACCEPT
            sudo iptables -I INPUT 7 -s 52.120.0.0/14 -j ACCEPT

            sudo iptables -I OUTPUT 1 -p udp --dport 3478:3481 -j ACCEPT
            sudo iptables -I OUTPUT 2 -d 13.107.64.0/18 -j ACCEPT
            sudo iptables -I OUTPUT 3 -d 52.112.0.0/14 -j ACCEPT
            sudo iptables -I OUTPUT 4 -d 52.120.0.0/14 -j ACCEPT            
            ;; # end: open msteams

        *)
            echo "Error: invalid program to allow through firewall ($program)"
            exit -1
            ;;
    esac
    ;; # end: open 

close)
    program=${POSITIONAL[0]}

    case $program in
        # proxmox virtualization tool
        proxmox)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        grep -no -m 1 '8006' |\
                        cut -f1 -d':'`
                    rule=$(( rule -1 ))        
                    [ ${rule} -gt 0 ] && sudo iptables -D ${chain} ${rule} || break
                done
            done
            ;; # end: close proxmox

        # SSH
        ssh)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        grep -no -m 1 '22' |\
                        cut -f1 -d':'`
                    rule=$(( rule -1 ))        
                    [ ${rule} -gt 0 ] && sudo iptables -D ${chain} ${rule} || break
                done
            done
            ;; # end: close SSH            

        # Microsoft Teams
        msteams)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        grep -no -m 1 '3478:3481|13.107.64.0|52.112.0.0|52.120.0.0' |\
                        cut -f1 -d':'`
                    rule=$(( rule -1 ))        
                    [ ${rule} -gt 0 ] && sudo iptables -D ${chain} ${rule} || break
                done
            done
            ;; # end: close msteams

        *)
            echo "Error: invalid operation for proxmox ($operation)"
            exit -1
            ;; 
    esac 
    ;; # end: close  

stop)
    sudo iptables -F INPUT
    sudo iptables -P INPUT ACCEPT

    sudo iptables -F FORWARD
    sudo iptables -P FORWARD ACCEPT

    for chain in INPUT OUTPUT; do
        while :; do
            rule=`sudo iptables -S ${chain} |\
                grep -no -m 1 '3478:3481|13.107.64.0|52.112.0.0|52.120.0.0' |\
                cut -f1 -d':'`
            rule=$(( rule -1 ))        
            [ ${rule} -gt 0 ] && sudo iptables -D ${chain} ${rule} || break
        done
    done

    if [ ${WITH_OUTPUT} -eq 1 ]; then 
        sudo iptables -F OUTPUT
        sudo iptables -P OUTPUT ACCEPT
    fi
    ;; # fim: action stop

debug)

    if [ ${DEBUG} -eq 1 ]; then 
        sudo iptables -t raw -A PREROUTING -p tcp --dport 53 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 53 -j TRACE
        sudo iptables -t raw -A INPUT -p tcp --dport 53 -j TRACE
        sudo iptables -t raw -A INPUT -p udp --dport 53 -j TRACE    

        sudo iptables -t raw -A PREROUTING -p tcp --dport 80 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 80 -j TRACE
        sudo iptables -t raw -A INPUT -p tcp --dport 80 -j TRACE
        sudo iptables -t raw -A INPUT -p udp --dport 80 -j TRACE    

        sudo iptables -t raw -A PREROUTING -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 443 -j TRACE
        sudo iptables -t raw -A INPUT -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A INPUT -p udp --dport 443 -j TRACE
    fi


    if [ ${DEBUG} -eq 1 ]; then 
        sudo iptables -t raw -A PREROUTING -p tcp --dport 53 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 53 -j TRACE   
        sudo iptables -t raw -A OUTPUT -p tcp --dport 53 -j TRACE
        sudo iptables -t raw -A OUTPUT -p udp --dport 53 -j TRACE

        sudo iptables -t raw -A PREROUTING -p tcp --dport 80 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 80 -j TRACE
        sudo iptables -t raw -A OUTPUT -p tcp --dport 80 -j TRACE
        sudo iptables -t raw -A OUTPUT -p udp --dport 80 -j TRACE

        sudo iptables -t raw -A PREROUTING -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A PREROUTING -p udp --dport 443 -j TRACE
        sudo iptables -t raw -A OUTPUT -p tcp --dport 443 -j TRACE
        sudo iptables -t raw -A OUTPUT -p udp --dport 443 -j TRACE
    fi        



    ;;

*)
    echo "Invalid action: ${action}"
    exit -1
    ;;

esac

# sudo iptables -L

