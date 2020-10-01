#!/bin/bash

DEBUG=1
CONF_OUTPUT=0
WITH_TUN=0

remove_rules(){
    match="$1"
    for chain in INPUT OUTPUT; do
        while :; do
            rule=`sudo iptables -S ${chain} |\
                grep -no -m 1 "${match}" | head -1 |\
                cut -f1 -d':'`
            rule=$(( rule -1 ))        
            [ ${rule} -gt 0 ] && sudo iptables -D ${chain} ${rule} || break
        done
    done
}

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

    # allow incoming HTTP requests
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

    # allow incoming HTTPS inputs
    # sudo iptables -A INPUT -p tcp --sport 443 -j ACCEPT    

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

    # don't allow forward connections
    sudo iptables -A FORWARD -p tcp -j REJECT --reject-with tcp-reset
    sudo iptables -A FORWARD -p udp -j REJECT --reject-with icmp-host-unreachable

    sudo iptables -P FORWARD DROP

    ########################
    # OUTPUT configuration #
    ########################
    sudo iptables -F OUTPUT
    sudo iptables -P OUTPUT ACCEPT

    if [[ ${WITH_OUTPUT} -eq 1 ]]; then
        # temporary ACCEPT policy


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

    # allow_sites
    sudo iptables -P OUTPUT DROP
    ;; # fim: action start

open)
    program=${POSITIONAL[0]}

    input_rule=${POSITIONAL[1]}
    output_rule=${POSITIONAL[2]}

    [[ ${input_rule} -gt 1 ]] && input_rule=${input_rule} || input_rule=1
    [[ ${output_rule} -gt 1 ]] && output_rule=${output_rule} || output_rule=1

    case $program in

        # selected sites, as seen in $HOME/.allowed-sites files
        sites)
            for site in $(sudo cat "/root/allowed-sites"); do
                echo "Allowing ${site}"
                sudo iptables -I OUTPUT ${output_rule} -d ${site} -j ACCEPT
            done
            ;;

        # proxmox virtualization tool
        proxmox)
            sudo iptables -I INPUT ${input_rule} -p tcp --sport 8006 -j ACCEPT
            sudo iptables -I INPUT ${input_rule} -p udp --sport 8006 -j ACCEPT

            sudo iptables -I OUTPUT ${output_rule} -p udp --dport 8006 -j ACCEPT
            sudo iptables -I OUTPUT ${output_rule} -p tcp --dport 8006 -j ACCEPT       
            ;; # end: open proxmox

        # SSH 
        ssh)
            sudo iptables -I INPUT 4 -p tcp --dport 22 -j ACCEPT
            sudo iptables -I INPUT 5 -p udp --dport 22 -j ACCEPT

            sudo iptables -I OUTPUT 1 -p udp --sport 22 -j ACCEPT
            sudo iptables -I OUTPUT 2 -p tcp --sport 22 -j ACCEPT        
            ;; # end: open ssh            

        # Microsoft Teams
        msteams)
            # sudo iptables -I INPUT 4 -p udp --sport 3478:3481 -j ACCEPT
            # sudo iptables -I INPUT 5 -s 13.107.64.0/18 -j ACCEPT
            # sudo iptables -I INPUT 6 -s 52.112.0.0/14 -j ACCEPT
            # sudo iptables -I INPUT 7 -s 52.120.0.0/14 -j ACCEPT
            # sudo iptables -I INPUT 3 -p udp --sport 3478:3481 -j ACCEPT

            sudo iptables -I OUTPUT ${output_rule} -p udp --dport 3478:3481 -j ACCEPT
            sudo iptables -I OUTPUT ${output_rule} -d 13.107.64.0/18 -j ACCEPT
            sudo iptables -I OUTPUT ${output_rule} -d 52.112.0.0/14 -j ACCEPT
            sudo iptables -I OUTPUT ${output_rule} -d 52.120.0.0/14 -j ACCEPT         
            ;; # end: open msteams

        *)
            echo "Error: invalid program to allow through firewall ($program)"
            exit -1
            ;;
    esac
    ;; # end: open 

close)
    program=${POSITIONAL[0]}

    input_rule=${POSITIONAL[1]}
    output_rule=${POSITIONAL[2]}

    case $program in

        # open selected sites
        sites)
            for site in $(cat /root/blocked-sites); do
                echo "Blocking ${site} ..."
                sudo iptables -I OUTPUT ${output_rule} -d ${site} -j DROP
            done
            ;; #end: close sites

        # proxmox virtualization tool
        proxmox)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        egrep -no -m 1 '8006' | head -1 |\
                        cut -f1 -d':'`
                    rule=$(( rule -1 ))     
                    [[ ${DEBUG} -eq 1 ]] && echo "DEBUG: close proxmox ${chain} ${rule}"
                    [[ ${rule} -gt 0 ]] && sudo iptables -D ${chain} ${rule} || break
                done
            done
            ;; # end: close proxmox

        # SSH
        ssh)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        grep -no -m 1 '22' | head -1 |\
                        cut -f1 -d':'`
                    rule=$(( rule -1 ))
                    [[ $DEBUG -eq 1 ]] && echo "DEBUG: close ssh ${chain} ${rule}"
                    [[ $rule -gt 0 ]] && sudo iptables -D ${chain} ${rule} || break
                done
            done
            ;; # end: close SSH        

        # Microsoft Teams
        msteams)
            for chain in INPUT OUTPUT; do
                while :; do
                    rule=`sudo iptables -S ${chain} |\
                        egrep -n -m 1 '3478:3481|13\.107\.64\.0|52\.112\.0\.0|52\.120\.0\.0' |\
                        cut -f1 -d':'`                                        
                    rule=$(( rule -1 ))
                    [[ $DEBUG -eq 1 ]] && echo "DEBUG: close msteams ${chain} ${rule}"
                    [[ $rule -gt 0 ]] && sudo iptables -D ${chain} ${rule} || break
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
            [[ ${rule} -gt 0 ]] && sudo iptables -D ${chain} ${rule} || break
        done
    done

    if [[ ${WITH_OUTPUT} -eq 1 ]]; then 
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

