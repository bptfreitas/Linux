#!/bin/bash

FS_MOUNT_POINT=/media/VMs


fsSzB4_sm_wr_bytes="`du -sh ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzB4_sm_wr_blocks="`du -s ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "* Starting filesystem small file creation benchmark ... *"

echo "Filesystem size before writing (bytes): ${fsSzB4_sm_wr_bytes}"
echo "Filesystem size before writing (blocks): ${fsSzB4_sm_wr_blocks}"

{ time for i in $(seq 1 50000)
do
echo "teste$i" > ${FS_MOUNT_POINT}/teste$i.dat
done } 2> results_small_wr.tmp

awk ' { if (NR==2) print $2 } ' results_small_wr.tmp

fsSzAfter_sm_wr_bytes="`du -sh ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_wr_blocks="`du -s ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size after writing (bytes): ${fsSzAfter_sm_wr_bytes}"
echo "Filesystem size after writing (blocks): ${fsSzAfter_sm_wr_blocks}"

echo "* Starting filesystem small file deletion benchmark ... *"
{ time for i in $(seq 1 50000)
do
rm ${FS_MOUNT_POINT}/teste$i.dat
done } 2> results_small_del.tmp

awk ' { if (NR==2) print $2 } ' results_small_del.tmp

# size in megabytes
LARGE_FILE_SZ=1024

src_code="
#include <stdio.h>

int main(){
    FILE *fd = NULL, i;
    char data[512];

    fd = fopen('$FS_MOUNT_POINT', 'w');

    for ( i = 0; i < 512; data[i++] = 'X' );



    fclose(fd);
}
";








