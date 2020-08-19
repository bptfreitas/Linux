#!/bin/bash

DEBUG=0
if [[ $DEBUG -eq 1 ]]; then 
	DEV=""
	PARTITION_NAME=data
	MOUNT_POINT=/tmp/mnt
	KEYFILE=/tmp/keyfile
else
	while [[ $# -gt 0 ]]
	do
		key="$1"

		case $key in
			--partition|-p)
			PARTITION_NAME="$2"
			shift # past argument
			shift # past value
			;;

			--device|-d)
			DEV="$2"
			shift # past argument
			shift # past value
			;;

			--keyfile|-k)
			KEYFILE="$2"
			shift # past argument
			shift # past value
			;;

			--mount-point|-m)
			MOUNT_POINT="$2"
			shift # past argument
			shift # past value
			;;

			*)    # unknown option
			POSITIONAL+=("$1") # save it in an array for later
			shift # past argument
			;;
		esac
	done
	set -- "${POSITIONAL[@]}" # restore positional parameters-
fi

if [[ "${DEV}" == "" ]]; then
	echo "Device not set"
	exit
elif [[ ! -e "${DEV}" ]]; then
	echo "Device does not exist: ${DEV}"
	exit
else
	echo "Device to encrypt: ${DEV}"
fi

if [[ "${MOUNT_POINT}" == "" ]]; then
	echo "Mount point not set"
	exit
else
	echo "Mount point: ${MOUNT_POINT}"
fi

if [[ "${PARTITION_NAME}" == "" ]]; then
	echo "Partition name not set"
	exit
else
	echo "Partition name: ${PARTITION_NAME}"
fi

if [[ "${KEYFILE}" == "" ]]; then
	echo "Keyfile name not set"
	exit
else
	echo "Keyfile: ${KEYFILE}"
fi

while :; do
	echo -n "Proceed? [y/n]: "
	read -n 1 ans
	echo 
	[[ $ans == "n" ]] && exit
	[[ $ans == "y" ]] && break || echo "Invalid answer"
done

echo "Unmounting device ..."

sudo umount ${DEV}

echo "Formatting LUKS device ..."

sudo cryptsetup luksFormat ${DEV}
[ $? -ne 0 ] && exit -1

echo "Openning LUKS device ..."

sudo cryptsetup luksOpen ${DEV} ${PARTITION_NAME}
[ $? -ne 0 ] && exit -1


if [[ ! -d ${MOUNT_POINT} ]]; then 
    echo "Creating ${MOUNT_POINT} ..."
    sudo mkdir -p ${MOUNT_POINT}
else
    echo "${MOUNT_POINT} already exists"
fi

sudo mkfs.ext4 /dev/mapper/${PARTITION_NAME}

sudo mount /dev/mapper/${PARTITION_NAME} ${MOUNT_POINT}/${PARTITION_NAME}

echo -e "/dev/mapper/${PARTITION_NAME}   ${MOUNT_POINT}/${PARTITION_NAME} ext4    defaults    0   2" | sudo tee -a /etc/fstab

dd if=/dev/urandom of=${KEYFILE} bs=1024 count=4

chmod 400 ${KEYFILE}

echo -e -n "${PARTITION_NAME}  ${DEV}       ${KEYFILE}" | sudo tee -a /etc/crypttab

sudo cryptsetup -v luksAddKey ${DEV} ${KEYFILE}



