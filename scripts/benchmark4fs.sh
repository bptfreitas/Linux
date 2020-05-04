#!/bin/bash

FS_MOUNT_POINT=/media/VMs # mount point to create filesystems
TOTAL_SMALL_FILES=10 # total files to create in each test
TOTAL_LARGE_FILES=${TOTAL_SMALL_FILES}
LARGE_FILE_SZ=$((4*1024*1024)) # size in bytes
BUFFER_SZ=512
BLOCK_QTD=$(( LARGE_FILE_SZ / BUFFER_SZ ))

fsSzB4_sm_wr_bytes="`du -sh ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzB4_sm_wr_blocks="`du -s ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size before writing starting benchmarks (bytes): ${fsSzB4_sm_wr_bytes}"
echo "Filesystem size before writing starting benchmarks (blocks): ${fsSzB4_sm_wr_blocks}"

echo -e "\n* Starting filesystem small file creation benchmark *"

{ time for i in $(seq 1 ${TOTAL_SMALL_FILES})
do
echo "teste$i" > ${FS_MOUNT_POINT}/teste$i.dat
done } 2> results_small_wr.tmp

awk ' { if (NR==2) print $2 } ' results_small_wr.tmp

fsSzAfter_sm_wr_bytes="`du -sh ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_wr_blocks="`du -s ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size after writing small files (bytes): ${fsSzAfter_sm_wr_bytes}"
echo "Filesystem size after writing small files (blocks): ${fsSzAfter_sm_wr_blocks}"

echo -e "\n* Starting filesystem small file deletion benchmark *"
{ time for i in $(seq 1 ${TOTAL_SMALL_FILES})
do
rm ${FS_MOUNT_POINT}/teste$i.dat
done } 2> results_small_del.tmp

awk ' { if (NR==2) print $2 } ' results_small_del.tmp

fsSzAfter_sm_del_bytes="`du -sh ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_del_blocks="`du -s ${FS_MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size after erasing small files (bytes): ${fsSzAfter_sm_del_bytes}"
echo "Filesystem size after erasing small files (blocks): ${fsSzAfter_sm_del_blocks}"

src_code="
#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char **argv){
    FILE *fd = NULL;
    int i,n,fn;
    char buffer[${BUFFER_SZ}],filename[32];

    if (argc==1){
        return -1;
    }

    fn = atoi(argv[1]);

    n = sprintf(filename,\"$FS_MOUNT_POINT/teste%d\",fn);

    fd = fopen(filename, \"w\");

    for ( i = 0; i < ${BUFFER_SZ}; buffer[i++] = 'X' );

    for ( i = 0; i < ${BLOCK_QTD} ; i++ ){
        fwrite( buffer,  sizeof(char),  ${BUFFER_SZ} , fd );
    }

    fclose(fd);
}
";

echo "${src_code}" > /tmp/main.c
gcc /tmp/main.c -o /tmp/largeFileBenchmark

