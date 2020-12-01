#!/bin/bash

TEST=$1

if [[ $TEST -eq 1 ]]; then
	export PROXMOX_FUNCTIONS_LOG="/tmp/proxmox_functions.log"
	export PROXMOX_FUNCTIONS_LOG_CMD="tee -a ${PROXMOX_FUNCTIONS_LOG}"
	> $PROXMOX_FUNCTIONS_LOG
else 
	export PROXMOX_FUNCTIONS_LOG=/var/log/proxmox_functions.log
	export PROXMOX_FUNCTIONS_LOG_CMD="sudo tee -a ${PROXMOX_FUNCTIONS_LOG}"
fi

function proxmox_adduser(){
	local USERNAME=$1	
	local PASSWORD=$2
	local NODE_TO_MIGRATE=$3
	local VM_ID=$4

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
		echo -e "`date +%c`: User added. Cloning VM ${VM_TO_CLONE} to ${VM_ID} " | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else 
		echo "`date +%c`: [ERROR] Failed to add user" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1
	fi

	tail -n  ${PROXMOX_FUNCTIONS_LOG}
}

function proxmox_add_cloned_VM(){

	echo "`date +%c`: $0" | ${PROXMOX_FUNCTIONS_LOG_CMD}

	# error checking 

	if [[ $# -ne 3 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#";
		return
	fi

	# availing parameters
	local VM_ID=$1
	local NODE_TO_MIGRATE=$2

	# starting script

	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM '${VM_ID}' created from '${VM_TO_CLONE}'" | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1
	fi

	if [[ "${NODE_TO_MIGRATE}" != "" ]]; then
		echo "`date +%c`: Migrating ${VM_ID} to ${NODE_TO_MIGRATE}" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		fi	
	fi

	tail -n  ${PROXMOX_FUNCTIONS_LOG}
}

function proxmox_adduser_with_cloned_VM(){

	echo "`date +%c`: $0" | ${PROXMOX_FUNCTIONS_LOG_CMD}

	# error checking 

	if [[ $# -ne 3 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#";
		return
	fi 

	if [[ ${total_proxmox_nodes} -eq 0 ]]; then 
		echo "`date +%c`: [ERROR] proxmox nodes not defined ";
		return -1
	fi

	# availing parameters
	local USERNAME=$1
	local PASSWORD=$2
	local VM_TO_CLONE=$3
	local VM_ID=$4
	local NODE_TO_MIGRATE=$5

	# starting script

	echo "`date +%c`: Adding user '${USERNAME}' to proxmox"
	
	pveum useradd ${USERNAME}@pve --password ${PASSWORD};
	if [[ $? -eq 0 ]]; then
		echo -e "`date +%c`: User added. Cloning VM ${VM_TO_CLONE} to ${VM_ID} " | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else 
		echo "`date +%c`: [ERROR] Failed to add user" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1
	fi

	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM created. Modifying permissions" | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1
	fi

	pveum aclmod /vms/${VM_ID} -user ${USERNAME}@pve -role AlunoCefet
	if [[ $? -eq 0 ]]; then 
		echo "`date +%c`: Permissions changed" | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else
		echo "`date +%c`: [ERROR] Failed to change permissions" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1	
	fi

	if [[ "${NODE_TO_MIGRATE}" != "" ]]; then
		echo "`date +%c`: Migrating ${VM_ID} to ${NODE_TO_MIGRATE}" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		fi	
	fi

	tail -n  ${PROXMOX_FUNCTIONS_LOG}
}

function proxmox_add_cloned_VM_to_users(){

	echo "`date +%c`: $0" | ${PROXMOX_FUNCTIONS_LOG_CMD}	

	# parameter checking

	if [[ $# -lt 4 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $# - must be at least 2" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return
	fi

	########################
	# parameter definition #
	########################
	local VM_TO_CLONE=$1
	shift
	local VM_ID=$2
	shift
	# if this parameter equals to 'none', don't migrate cloned VM
	local NODE_TO_MIGRATE=$3
	shift
	local USERS=$*

	###################
	# starting script #
	###################

	# cloning VM
	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM created. Modifying permissions" | ${PROXMOX_FUNCTIONS_LOG_CMD}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		return -1
	fi	

	# adding cloned VMs to users
	echo "`date +%c`: VM to add: $VM_ID" | ${PROXMOX_FUNCTIONS_LOG_CMD}

	for user in $USERS; do
		pveum aclmod /vms/${VM_ID} -user ${user}@pve -role AlunoCefet
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Added VM '${VM_ID}' to '$user'" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		else
			echo "`date +%c`: [ERROR] Failed to add VM '${VM_ID}' to '$user'" | ${PROXMOX_FUNCTIONS_LOG_CMD}
		fi		
	done

	# if NODE_TO_MIGRATE is different than 'none', migrate it to specified node
	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		echo "`date +%c`: Migrating VM '${VM_ID}' to ${NODE_TO_MIGRATE}" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate" | ${PROXMOX_FUNCTIONS_LOG_CMD} 
		fi	
	fi

	tail -n  ${PROXMOX_FUNCTIONS_LOG}

	return;
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