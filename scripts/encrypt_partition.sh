#!/bin/bash

DEV=/dev/sda8
PARTITION_NAME=data
MOUNT_POINT=/media/data

sudo umount ${DEV}

sudo cryptsetup luksFormat ${DEV}
[ $? -ne 0 ] && exit -1

sudo cryptsetup luksOpen ${DEV} ${PARTITION_NAME}
[ $? -ne 0 ] && exit -1


if [ ! -d ${MOUNT_POINT} ]; then 
    echo "Creating ${MOUNT_POINT} ..."
    sudo mkdir -p ${MOUNT_POINT}
else
    echo "${MOUNT_POINT} already exists"
fi

sudo mount /dev/mapper/data /media/data

