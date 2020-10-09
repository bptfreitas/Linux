#!/bin/bash

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
export TOTAL_PROXMOX_NODES=${#PROXMOX_NODES[@]}
export NODE_TO_MIGRATE=0 
export VM_TO_CLONE=9004

function proxmox_adduser(){
	USERNAME=$1
	PASSWORD=$2
	VM_ID=$3

	echo "Creating VM ${VM_ID} for user '${USERNAME}'" >> ${LOG_ADDUSER} 
	pvum useradd ${USERNAME} --password ${PASSWORD}
	qm clone ${VM_TO_CLONE} ${VM_ID} 
	if [[ $? -eq 0 ]]; then 
		for i in `seq ${TOTAL_PROXMOX_NODES}`; do 
			NODE_TO_MIGRATE=$(( (NODE_TO_MIGRATE + 1) % TOTAL_PROXMOX_NODES ))
			echo "Migrating VM ${VM_ID} to node ${PROXMOX_NODES[$NODE_TO_MIGRATE]}" 

			qm migrate ${VM_ID} ${PROXMOX_NODES[$NODE_TO_MIGRATE]} 
			if [[ $? -eq 0 ]]; then 
				echo "Migration concluded. Changing permissions to VM" >> ${LOG_ADDUSER} 
				pveum aclmod /vms/${VM_ID} -user ${USERNAME}@pve -role AlunoCefet
                export NODE_TO_MIGRATE
				break 
			else
				if [[ $i -eq ${TOTAL_PROXMOX_NODES} ]]; then 
					echo "Migration to all PROXMOX_NODES failed" >> ${LOG_ADDUSER} 
				else 
					echo "Migration ${i}/${TOTAL_PROXMOX_NODES} failed. Trying next node." >> ${LOG_ADDUSER}
				fi
			fi
		done 
	else 
		echo "Error cloning VM ${VM_TO_CLONE} to ${VM_ID}" >> ${LOG_ADDUSER}
	fi
}

