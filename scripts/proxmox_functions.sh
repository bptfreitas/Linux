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
	local USERNAME="$1"	
	local PASSWORD="$2"
	local COMMENT="$3"

	if [[ -n $COMMENT ]]; then
		COMMENT="--comment \"${COMMENT}\"";
	fi

	echo "`date +%c`: Adding user '${USERNAME}' to proxmox"
	
	pveum useradd ${USERNAME}@pve --password ${PASSWORD} ${COMMENT};
	if [[ $? -eq 0 ]]; then
		echo -e "`date +%c`: User ${USERNAME} added"
	else 
		echo "`date +%c`: [ERROR] Failed to add user"
		return -1
	fi

	tail -n  ${PROXMOX_FUNCTIONS_LOG}
}

function proxmox_add_cloned_VM(){

	VM_TO_CLONE="$1"
	VM_ID="$2"
	NAME="$3"

	if [[ -n $NAME ]]; then
		NAME="--name \"${NAME}\"";
	fi

	echo "`date +%c`: Creating VM ${VM_ID} from full clone of VM ${VM_TO_CLONE}"

	qm clone ${VM_TO_CLONE} ${VM_ID} --full ${NAME}
	if [[ $? -ne 0 ]]; then
		echo "`date +%c`: [ERROR] Failed to clone VM ${VM_TO_CLONE} to ${VM_ID}"		
		return -1
	fi
}


function proxmox_add_users_to_VM(){

	TEMP_LOG=/tmp/proxmox_functions.log

	echo "`date +%c`: $0" >> ${TEMP_LOG}

}
	

function proxmox_adduser_with_cloned_VM(){

	echo "`date +%c`: ${FUNCNAME[0]} $*"

	TEMP_LOG=/tmp/proxmox_add_cloned_VM_to_users.log

	> ${TEMP_LOG}

	# parameter checking
	if [[ $# -ne 6 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $# - must 6" >> ${TEMP_LOG}
		cat ${TEMP_LOG}
		return -1
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
	local USER=$1
	shift
	local PASSWORD=$1
	shift
	local COMMENT=$1


	###################
	# starting script #
	###################
	if [[ -n ${COMMENT} ]]; then
		COMMENT="--comment \"${COMMENT}\"";
	fi

	# adding user
	echo "`date +%c`: Adding user '${USER}' to proxmox";

	pveum useradd ${USER}@pve --password \"${PASSWORD}\" ${COMMENT};
	if [[ $? -ne 0 ]]; then
		echo "`date +%c`: [ERROR] Failed to add user ${USER}" >> ${TEMP_LOG}
		return -1;
	fi


	# cloning VM
	echo "`date +%c`: Creating VM ${VM_ID} from full clone of VM ${VM_TO_CLONE}" >> ${TEMP_LOG}

	qm clone ${VM_TO_CLONE} ${VM_ID} --full
	if [[ $? -ne 0 ]]; then
		echo "`date +%c`: [ERROR] Failed to clone VM ${VM_TO_CLONE}" >> ${TEMP_LOG} 
		tail -2 ${TEMP_LOG};
		return -1
	fi

	# adding cloned VMs to user
	echo "`date +%c`: Adding VM ${VM_ID} to user ${USER}" >> ${TEMP_LOG}

	pveum aclmod /vms/${VM_ID} -user ${USER}@pve -role AlunoCefet
	if  [[ $? -ne 0 ]]; then 
		echo "`date +%c`: [ERROR] Failed to add VM '${VM_ID}' to '$user'" >> ${TEMP_LOG}
		tail -2 ${TEMP_LOG}
		return -1;
	fi

	# adding selected storages to user
	for storage in distros; do
		pveum aclmod /storage/${storage} -user ${USER}@pve -role AlunoCefet
		if  [[ $? -ne 0 ]]; then 
			echo "`date +%c`: [ERROR] Failed to add storage '${storage}' to '$USER'" >> ${TEMP_LOG}
			tail -2 ${TEMP_LOG}
			return -1;
		fi
	done

	# if NODE_TO_MIGRATE is different than 'none', migrate it to specified node
	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		echo "`date +%c`: Migrating VM '${VM_ID}' to ${NODE_TO_MIGRATE}" >> ${TEMP_LOG}
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -ne 0 ]]; then
			echo "`date +%c`: [ERROR] couldn't migrate '${VM_ID}' to '${NODE_TO_MIGRATE}'" >> ${TEMP_LOG}
			tail -2 ${TEMP_LOG}
			return -1
		fi
	fi
	
	return 0;
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
