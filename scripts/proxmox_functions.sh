#!/bin/bash

TEST=$1

LOG_ADDUSER=proxmox_addusers.log
if [[ $TEST -eq 1 ]]; then 
	> ${LOG_ADDUSER}
fi

export VM_TO_CLONE=9004

function proxmox_adduser_with_cloned_VM(){
	local USERNAME=$1
	local PASSWORD=$2
	local VM_ID=$3
	local NODE_TO_MIGRATE=$4

	if [[ $# -ne 4 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments: $#";
		return
	fi

	echo "`date +%c`: Adding user '${USERNAME}' to proxmox"
	
	pveum useradd ${USERNAME}@pve --password ${PASSWORD};
	if [[ $? -eq 0 ]]; then
		echo -e "`date +%c`: User added. Cloning VM ${VM_TO_CLONE} to ${VM_ID} " >> ${LOG_ADDUSER}
	else 
		echo "`date +%c`: [ERROR] Failed to add user" >> ${LOG_ADDUSER}
		return -1
	fi

	qm clone ${VM_TO_CLONE} ${VM_ID} --full
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

	if [[ "${NODE_TO_MIGRATE}" != "" ]]; then
		echo "`date +%c`: Migrating ${VM_ID} to ${NODE_TO_MIGRATE}" >> ${LOG_ADDUSER} 
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		if [[ $? -eq 0 ]]; then 
			echo "`date +%c`: Migration concluded" >> ${LOG_ADDUSER} 
		else
			echo "`date +%c`: [ERROR] couldn't migrate" >> ${LOG_ADDUSER} 
		fi	
	fi

	tail -n 5 ${LOG_ADDUSER}
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