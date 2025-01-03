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

export PROXMOX_DEFAULT_VM_STORAGES=distros

export PROXMOX_DEFAULT_VM_ROLE=AlunoCefet

export PROXMOX_DEFAULT_VM_POOL=""

function proxmox_adduser(){
	local USERNAME="$1"	
	local PASSWORD="$2"
	local COMMENT="$3"

	if [[ -n $COMMENT ]]; then
		COMMENT="--comment \"${COMMENT}\"";
	fi
	
	pveum useradd ${USERNAME}@pve --password ${PASSWORD} ${COMMENT};
}

function proxmox_clone_VM(){

	local VM_TO_CLONE="$1"
	local VM_ID="$2"
	local NAME="$3"

	if [[ -n $NAME ]]; then
		NAME="--name \"${NAME}\"";
	fi

	echo "`date +%c`: Creating VM ${VM_ID} from full clone of VM ${VM_TO_CLONE}"

	qm clone ${VM_TO_CLONE} ${VM_ID} ${NAME} --full 
	if [[ $? -ne 0 ]]; then
		echo "`date +%c`: [ERROR] Failed to clone VM ${VM_TO_CLONE} to ${VM_ID}"		
		return -1
	fi

	return 0;
}

function proxmox_add_users_to_VM(){

	if [[ $? -lt 3 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments"
		return -1;
	fi

	VM_ID=$1
	shift

	USERS=$*

	for user in $USERS; do

		pveum aclmod /vms/${VM_ID} -user ${user}@pve -role ${PROXMOX_DEFAULT_VM_ROLE} 

		# adding selected storages to user
		for storage in ${PROXMOX_DEFAULT_VM_STORAGES}; do
			pveum aclmod /storage/${storage} -user ${user}@pve
		done

	done

	return 0;

}


function proxmox_add_users_to_cloned_VM(){

	if [[ $# -lt 5 ]]; then
		echo "`date +%c`: [ERROR] Invalid number of arguments"
		return 1;
	fi

	local VM_TO_CLONE=$1
	shift

	local VM_ID=$1
	shift

	# must be separated by a :
	local VM_NAME=$1
	shift

	local NODE_TO_MIGRATE=$1
	shift

	local USERS=$*

	# TODO: Small parameter checking - all of them must not be empty to continue

	###################
	# starting script #
	###################
	echo "VM to clone: ${VM_TO_CLONE}"

	echo "VM ID: ${VM_ID}"

	echo "Node to migrate: ${NODE_TO_MIGRATE}"

	echo "Users: ${USERS}"

	echo "VM name: ${VM_NAME}"

	local VM_POOL_CMD=""
	# if pool is set, add the cloned VM to it
	if [[ "${PROXMOX_DEFAULT_VM_POOL}" != "" ]]; then

		echo "Pool: ${PROXMOX_DEFAULT_VM_POOL}"

		VM_POOL_CMD="--pool ${PROXMOX_DEFAULT_VM_POOL}"

	fi			

	qm clone ${VM_TO_CLONE} ${VM_ID} \
		--name ${VM_NAME} \
		${VM_POOL_CMD} \
		--full

	[[ $? -ne 0 ]] && return 1;

	# qm snapshot ${VM_ID} estado_inicial

	# [[ $? -ne 0 ]] && return 1;

	for user in ${USERS}; do

		# adding permission to VM for the user
		pveum aclmod /vms/${VM_ID} -user ${user}@pve -role ${PROXMOX_DEFAULT_VM_ROLE} 

		[[ $? -ne 0 ]] && return 1;

		# adding selected storages to user
		for storage in ${PROXMOX_DEFAULT_VM_STORAGES}; do
			pveum aclmod /storage/${storage} -user ${user}@pve -role ${PROXMOX_DEFAULT_VM_ROLE}

			[[ $? -ne 0 ]] && return 1;
		done			

	done
	
	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}

		[[ $? -ne 0 ]] && return 1;

	fi

	return 0;
}

function proxmox_mass_vm_destroy(){

	echo "Removing VMs specified on 'vms_to_destroy' ..."

	for vm in $(cat vms_to_destroy); do
			echo $vm;
			qm unlock $vm;
			qm stop $vm;
			[[ $? -eq 0 ]] && qm destroy $vm; 
	done
}

	

function proxmox_adduser_with_cloned_VM(){

	echo "`date +%c`: ${FUNCNAME[0]} $*"

	TEMP_LOG=/tmp/proxmox_add_cloned_VM_to_users.log
	
	set -x

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

	local NAME=""
	
	###################
	# starting script #
	###################
	if [[ -n ${COMMENT} ]]; then
		NAME="--name ${COMMENT}-${USER//[\. ]/-}";
		COMMENT="--comment \"${COMMENT}\"";
	else 
		NAME="--name \"${USER//\./-}\"";
	fi

	# adding user
	echo "`date +%c`: Adding user '${USER}' to proxmox" | tee -a ${TEMP_LOG};

	pveum useradd ${USER}@pve --password \"${PASSWORD}\" ${COMMENT};
	[[ $? -ne 0 ]] && return -1

	# cloning VM
	echo "`date +%c`: Creating VM ${VM_ID} from full clone of VM ${VM_TO_CLONE}" | tee -a ${TEMP_LOG}

	qm clone ${VM_TO_CLONE} ${VM_ID} ${NAME} --full
	[[ $? -ne 0 ]] && return -1

	# adding cloned VMs to user
	echo "`date +%c`: Adding VM ${VM_ID} to user ${USER}" >> ${TEMP_LOG}

	pveum aclmod /vms/${VM_ID} -user ${USER}@pve -role AlunoCefet
	[[ $? -ne 0 ]] && return -1
	
	# adding selected storages to user
	for storage in distros; do
		pveum aclmod /storage/${storage} -user ${USER}@pve -role AlunoCefet
		[[ $? -ne 0 ]] && return -1
	done

	# if NODE_TO_MIGRATE is different than 'none', migrate it to specified node
	if [[ "${NODE_TO_MIGRATE}" != "none" ]]; then
		echo "`date +%c`: Migrating VM '${VM_ID}' to ${NODE_TO_MIGRATE}" >> ${TEMP_LOG}
		
		qm migrate ${VM_ID} ${NODE_TO_MIGRATE}
		[[ $? -ne 0 ]] && return -1 
	fi
	
	set +x
	
	return 0;
}

# This script writes a suspend routine to disk on /root/proxmox_shutdown_VMs.sh
# This is meant to be ran with crontab 
# By default, it will run on 4 AM each day, shutting down all VMs on the file /root/VMs_to_shutdown.txt

function proxmox_create_suspend_routine(){

	cat > /root/proxmox_suspend_VMs.sh <<EOF
#!/usr/bin/sh

AWK_BIN=/usr/bin/awk
GREP_BIN=/usr/bin/grep
QM_BIN=/usr/sbin/qm

for VM in \$(\${QM_BIN} list | \${GREP_BIN} running | \${AWK_BIN} '{ print \$1 }'); do

	echo "Hibernating \$VM ..."

	\${QM_BIN} suspend \$VM --todisk

done

EOF
	chmod +x /root/proxmox_suspend_VMs.sh
	echo "Add to the crontab file: "
	echo "0 4 * * * /usr/bin/sh /root/proxmox_suspend_VMs.sh"

}

function proxmox_create_stop_routine(){

	> /root/proxmox_stop_running_VMs.sh

	cat > /root/proxmox_stop_running_VMs.sh <<EOF
#!/usr/bin/bash

AWK_BIN=/usr/bin/awk
GREP_BIN=/usr/bin/grep
QM_BIN=/usr/sbin/qm

VM_IGNORE_LIST=/root/vms_to_keep_alive

if [[ ! -f \$VM_IGNORE_LIST ]]; then
	> \$VM_IGNORE_LIST
fi

for VM in \$(\${QM_BIN} list | \${GREP_BIN} running | \${AWK_BIN} '{ print \$1 }'); do

	\${GREP_BIN} -q \${VM} \${VM_IGNORE_LIST}

	if [[ \$? -ne 0 ]]; then 

		echo "Stopping \$VM ..."

		\${QM_BIN} unlock \$VM;

		\${QM_BIN} stop \$VM;

	else 

		echo "VM \${VM} on ignore list, skipping"

	fi

done

EOF
	chmod a+x /root/proxmox_stop_running_VMs.sh

	crontab -l > /tmp/crontab.old

	crontab_job="0 4 * * * /usr/bin/bash /root/proxmox_stop_running_VMs.sh"

	grep -q "${crontab_job}" /tmp/crontab.old

	if [[ $? -eq 0 ]]; then 

		echo "crontab job already exists, skipping step"

	else

		echo "${crontab_job}" | tee -a /tmp/crontab.old

		crontab /tmp/crontab.old

	fi
	
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
