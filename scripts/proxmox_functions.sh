#!/bin/bash

TEST=$1

LOG_ADDUSER=proxmox_addusers.log
> ${LOG_ADDUSER}

PROXMOX_NODES[0]=proxmox 
PROXMOX_NODES[1]=proxmox2 
PROXMOX_NODES[2]=proxmox3 
PROXMOX_NODES[3]=proxmox4 
PROXMOX_NODES[4]=proxmox5 
PROXMOX_NODES[5]=proxmox6 
PROXMOX_NODES[6]=proxmox7 
PROXMOX_NODES[7]=proxmox8 

export PROXMOX_NODES
export NEXT_NODE_TO_MIGRATE=0 
export VM_TO_CLONE=9004

function proxmox_adduser_with_cloned_VM(){
	USERNAME=$1
	PASSWORD=$2
	VM_ID=$3

	total_proxmox_nodes=${#PROXMOX_NODES[@]}

	if [[ $# -ne 3 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#";
		return
	fi 

	if [[ ${total_proxmox_nodes} -eq 0 ]]; then 
		echo "`date +%c`: [ERROR] proxmox nodes not defined ";
		return -1
	fi

	echo "`date +%c`: Adding user '${USERNAME}' to proxmox"
	
	pveum useradd ${USERNAME}@pve --password ${PASSWORD};
	if [[ $? -eq 0 ]]; then
		echo -e "`date +%c`: User added. Cloning VM ${VM_TO_CLONE} to ${VM_ID} " >> ${LOG_ADDUSER}
	else 
		echo "`date +%c`: [ERROR] Failed to add user" >> ${LOG_ADDUSER}
		return -1
	fi

	qm clone ${VM_TO_CLONE} ${VM_ID} # --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM created. Modifying permissions" >> ${LOG_ADDUSER}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM" >> ${LOG_ADDUSER}
		return -1
	fi

	pveum aclmod /vms/${VM_ID} -user ${USERNAME}@pve -role AlunoCefet
	if [[ $? -eq 0 ]]; then 
		echo "`date +%c`: Permissions changed" >> ${LOG_ADDUSER}
	else
		echo "`date +%c`: [ERROR] Failed to change permissions" >> ${LOG_ADDUSER}
		return -1	
	fi

	for i in `seq ${total_proxmox_nodes}`; do
		
		NEXT_NODE_TO_MIGRATE=$(( (NEXT_NODE_TO_MIGRATE + 1) % total_proxmox_nodes ))

		echo "`date +%c`: Migrating VM ${VM_ID} to node ${PROXMOX_NODES[$NEXT_NODE_TO_MIGRATE]}" >> ${LOG_ADDUSER}
		
		qm migrate ${VM_ID} ${PROXMOX_NODES[$NEXT_NODE_TO_MIGRATE]} 		
		if [[ $? -eq 0 ]]; then 

			echo "`date +%c`: Migration concluded. Restarting VM. " >> ${LOG_ADDUSER} 
			
			qm stop ${VM_ID}
			qm start ${VM_ID}

			export NEXT_NODE_TO_MIGRATE
			break 
		else
			if [[ $i -eq ${TOTAL_PROXMOX_NODES} ]]; then 
				echo "`date +%c`: [ERROR] Migration to all PROXMOX_NODES failed" >> ${LOG_ADDUSER}
				return -1
			else 
				echo "`date +%c`: [FAIL] Migration ${i}/${total_proxmox_nodes} failed. Trying next node." >> ${LOG_ADDUSER}
			fi
		fi	
	done

	cat ${LOG_ADDUSER}
}

if [[ $TEST -eq 1 ]]; then

	shopt -s expand_aliases
	alias pvum="/bin/true"
	alias qm="/bin/true"

	TEST=1

	echo "TEST $TEST: no parameter check "; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM

	echo -e "\nTEST $TEST: parameter check"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "dummu user" "dummy password"

	echo -e "\nTEST $TEST: sucessfull run"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "test1" "abcd" "1111"
fi