#!/bin/bash

TEST=$1

if [[ $TEST -gt 0 ]]; then
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
	local VM_ID=$3

	local total_proxmox_nodes=${#PROXMOX_NODES[@]}

	if [[ $# -ne 3 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#";
		return -1
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

function proxmox_addusers_with_cloned_VM(){

	TEMP_LOG=/tmp/proxmox_functions.log

	echo "`date +%c`: $0" >> ${TEMP_LOG}

	# error checking 

	if [[ $# -lt 6 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#" >> ${TEMP_LOG}
		return
	fi

	# availing parameters
	local VM_TO_CLONE=$1
	shift;
	local VM_ID=$1
	shift;
	local NODE_TO_MIGRATE=$1
	shift;
	local COMMENT="$1"
	shift;

	local PASSWORD="$1"
	shift;
	local USERS=$*

	if [[ -n "$COMMENT"  ]]; then 
		COMMENT="--comment \"$COMMENT\""
	else
		COMMENT="";
	fi

	# starting script

	echo "`date +%c`: Cloning VM ${VM_TO_CLONE} to ${VM_ID}"

	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM created" >> ${TEMP_LOG}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM" >> ${TEMP_LOG}
		return -1
	fi

	for user in $USERS; do

		echo "`date +%c`: Adding user '${user}' to proxmox"

		pveum useradd ${user}@pve --password ${PASSWORD} ${COMMENT};
		if [[ $? -eq 0 ]]; then
			echo -e "`date +%c`: User added." >> ${TEMP_LOG}
		else 
			echo "`date +%c`: [ERROR] Failed to add user ${user}" >> ${TEMP_LOG}
			return -1
		fi		

		echo "`date +%c`: Modifying permissions for ${user}"

		pveum aclmod /vms/${VM_ID} -user ${user}@pve -role AlunoCefet
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Added permission to ${user} for VM ${VM_ID}" >> ${TEMP_LOG}
		else
			echo "`date +%c`: [ERROR] Failed to change permission" >> ${TEMP_LOG}
			return -1	
		fi

		pveum aclmod /storage/distros -user ${user}@pve -role AlunoCefet
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Added permission to ${user} for storage ${distros}" >> ${TEMP_LOG}
		else
			echo "`date +%c`: [ERROR] Failed to add permission to ${distros} for ${user}" >> ${TEMP_LOG}
			return -1	
		fi
	done

	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		echo "`date +%c`: Migrating ${VM_ID} to ${NODE_TO_MIGRATE}" >> ${TEMP_LOG} 
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" >> ${TEMP_LOG} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate" >> ${TEMP_LOG} 
		fi	
	fi

	# cat ${TEMP_LOG}
}

function proxmox_add_cloned_VM_to_users(){

	echo "`date +%c`: ${FUNCNAME[0]} $*"

	TEMP_LOG=/tmp/proxmox_add_cloned_VM_to_users.log

	> ${TEMP_LOG}

	# parameter checking

	if [[ $# -lt 4 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $# - must be at least 2" >> ${TEMP_LOG}
		cat ${TEMP_LOG}
		return
	fi

	########################
	# parameter definition #
	########################
	local VM_TO_CLONE=$1
	shift
	local VM_ID=$1
	shift
	# if this parameter equals to 'none', don't migrate cloned VM
	local NODE_TO_MIGRATE=$1
	shift
	local USERS=$*

	###################
	# starting script #
	###################

	# cloning VM
	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -eq 0 ]]; then
		echo "`date +%c`: VM ${VM_ID} cloned from ${VM_TO_CLONE}. Modifying permissions" >> ${TEMP_LOG}
	else
		echo "`date +%c`: [ERROR] Failed to clone VM ${VM_TO_CLONE}" >> ${TEMP_LOG} 
		cat ${TEMP_LOG}
		return 
	fi

	# adding cloned VMs to users
	echo "`date +%c`: Adding VM ${VM_ID} to selected users" >> ${TEMP_LOG}

	for user in $USERS; do
		pveum aclmod /vms/${VM_ID} -user ${user}@pve -role AlunoCefet
		pveum aclmod /storage/distros -user ${user}@pve -role AlunoCefet
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Added VM '${VM_ID}' to '${user}'" >> ${TEMP_LOG}
		else
			echo "`date +%c`: [ERROR] Failed to add VM '${VM_ID}' to '$user'" >> ${TEMP_LOG}		
		fi
	done

	# if NODE_TO_MIGRATE is different than 'none', migrate it to specified node
	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		echo "`date +%c`: Migrating VM '${VM_ID}' to ${NODE_TO_MIGRATE}" >> ${TEMP_LOG}
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" >> ${TEMP_LOG} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate '${VM_ID}' to '${NODE_TO_MIGRATE}'" >> ${TEMP_LOG}
			return
		fi
	fi

	cat ${TEMP_LOG}
	
	return;
}

if [[ $TEST -eq 1 ]]; then

	shopt -s expand_aliases
	alias pveum="/bin/true"
	alias qm="/bin/true"

	TEST=1

	echo "TEST $TEST: no parameter check "; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM

	echo -e "\nTEST $TEST: 2 parameter check"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "user" "password"

	echo -e "\nTEST $TEST: 3 parameters check"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "user" "password" "111"

	echo -e "\nTEST $TEST: 4 parameters check"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "user" "password" "111" "222"

	echo -e "\nTEST $TEST: 5 parameters check"; TEST=$((TEST + 1));
	proxmox_adduser_with_cloned_VM "user" "password" "111" "222" "node"
fi

if [[ $TEST -eq 2 ]]; then

	shopt -s expand_aliases
	alias pvum="/bin/true"
	alias qm="/bin/true"

	TEST=1

	echo "***Testing 'proxmox_add_cloned_VM_to_users'***"

	echo "TEST $TEST: no parameter check "; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users 

	echo -e "\nTEST $TEST: no users set"; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users "1234" "5678" "none"

	echo -e "\nTEST $TEST: single user/no migration"; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users "1234" "5678" "none" "joaozinho"

	echo -e "\nTEST $TEST: single user/with migration"; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users "1234" "5678" "dummy_node" "joaozinho"	

	echo -e "\nTEST $TEST: multiple users/no migration"; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users "1234" "5678" "none" "joaozinho" "mariazinha"

	echo -e "\nTEST $TEST: multiple users/with migration"; TEST=$((TEST + 1));
	proxmox_add_cloned_VM_to_users "1234" "5678" "dummy_node" "joaozinho" "mariazinha"
fi