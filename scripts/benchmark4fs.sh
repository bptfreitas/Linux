#!/bin/bash

#MOUNT_POINT=/media/VMs # mount point to -create filesystems

DEVICE=""
MOUNT_POINT=""

TOTAL_SMALL_FILES=50000
TOTAL_LARGE_FILES=${TOTAL_SMALL_FILES}

CLEAR_FS=0

LARGE_FILE_SZ=$((4*1024*1024)) # size in bytes
BUFFER_SZ=512
BLOCK_QTD=$(( LARGE_FILE_SZ / BUFFER_SZ ))

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --device)
            # mount point to create filesystems
            DEVICE=$2            
            shift # past argument
            shift # past value
            ;;

		# configures an output filter as well
        --mount-point)
            # mount point to create filesystems
            MOUNT_POINT=$2            
            shift # past argument
            shift # past value
            ;;

        --number-of-files)
            TOTAL_SMALL_FILES=$2 # total files to create in each test
            shift # past argument
            shift # past value
            ;;

        --clear-fs)
            CLEAR_FS=1
            shift
            ;;

		# unknown option
        *)    
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

[[ ! -b $DEVICE ]] &&\
    { echo "ERROR: Invalid device: $DEVICE" ; exit -1; }

[[ ! -d $MOUNT_POINT ]] &&\
    { echo "ERROR: Invalid mount point: $MOUNT_POINT" ; exit -1; }

mount -l | egrep "${DEVICE}" | egrep -q "${MOUNT_POINT}"

[[ $? -ne 0 ]] &&\
    { echo "ERROR: ${DEVICE} not mounted on ${MOUNT_POINT}" ; exit -1; } 

[[ ! -w "${MOUNT_POINT}" ]] &&\
    { echo "ERROR: Can't write in ${MOUNT_POINT}"; exit -1; }

BLOCK_SIZE=`sudo tune2fs -l ${DEVICE} | egrep 'Block size' | awk '{ print $3 }'`
[[ $? -ne 0 ]] &&\
    { echo "ERROR: can't get block size of device"; exit -1; }
echo "Partition block size: ${BLOCK_SIZE}"

[[ $CLEAR_FS -eq 1 ]] &&\
    { echo "Clearing filesystem ... "; rm $MOUNT_POINT/*; }    

fsSzB4_sm_wr_bytes="`du -s ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzB4_sm_wr_bytes_summary="`du -sh ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzB4_sm_wr_blocks="`du -s -B${BLOCK_SIZE} ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size before writing starting benchmarks (bytes): ${fsSzB4_sm_wr_bytes} (${fsSzB4_sm_wr_bytes_summary})"
echo "Filesystem size before writing starting benchmarks (blocks): ${fsSzB4_sm_wr_blocks}"

echo -e "\n***Starting filesystem small file creation benchmark***"

{ time for i in $(seq 1 ${TOTAL_SMALL_FILES})
do
echo "teste$i" > ${MOUNT_POINT}/teste$i.dat
done } 2> results_small_wr.tmp

echo "Elapsed time: `awk ' { if (NR==2) print $2 } ' results_small_wr.tmp`"

fsSzAfter_sm_wr_bytes="`du -s ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_wr_bytes_summary="`du -sh ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_wr_blocks="`du -s -B${BLOCK_SIZE} ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size after writing small files (bytes): ${fsSzAfter_sm_wr_bytes} (${fsSzAfter_sm_wr_bytes_summary})"
echo "Filesystem size after writing small files (blocks): ${fsSzAfter_sm_wr_blocks}"

echo -e "\n***Starting filesystem small file deletion benchmark***"
{ time for i in $(seq 1 ${TOTAL_SMALL_FILES})
do
rm ${MOUNT_POINT}/teste$i.dat
done } 2> results_small_del.tmp

echo "Elapsed time: `awk ' { if (NR==2) print $2 } ' results_small_del.tmp`"

fsSzAfter_sm_del_bytes="`du -s ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_del_bytes_summary="`du -sh ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"
fsSzAfter_sm_del_blocks="`du -s -B${BLOCK_SIZE} ${MOUNT_POINT} 2> /dev/null | awk '{ print $1 }'`"

echo "Filesystem size after erasing small files (bytes): ${fsSzAfter_sm_del_bytes} (${fsSzAfter_sm_del_bytes_summary})"
echo "Filesystem size after erasing small files (blocks): ${fsSzAfter_sm_del_blocks}"

# src_code="
# #include <stdio.h>
# #include <stdlib.h>

# int main(int argc, const char **argv){
#     FILE *fd = NULL;
#     int i,n,fn;
#     char buffer[${BUFFER_SZ}],filename[32];

#     if (argc==1){
#         return -1;
#     }

#     fn = atoi(argv[1]);

#     n = sprintf(filename,\"$MOUNT_POINT/teste%d\",fn);

#     fd = fopen(filename, \"w\");

#     for ( i = 0; i < ${BUFFER_SZ}; buffer[i++] = 'X' );

#     for ( i = 0; i < ${BLOCK_QTD} ; i++ ){
#         fwrite( buffer,  sizeof(char),  ${BUFFER_SZ} , fd );
#     }

#     fclose(fd);
# }
# ";

# echo "${src_code}" > /tmp/main.c
# gcc /tmp/main.c -o /tmp/largeFileBenchmark

## TODO: write a filesystem large file size ocupation benchmark

##########################################
## Starting filesystem speed benchmarks ##
##########################################

echo -e "\n***Starting filesystem speed benchmarks***"

ROOT=$PWD

cd "${MOUNT_POINT}"

fio --name=random-write \
    --ioengine=posixaio \
    --rw=randwrite \
    --bs=4k \
    --size=4g \
    --numjobs=1 \
    --iodepth=1 \
    --runtime=60 \
    --time_based \
    --end_fsync=1 2>&1 > "$ROOT/fs_randwrite_1job_4Gfs_4Kblocks.dat"

rm random-write*
cat $ROOT/fs_randwrite_1job_4Gfs_4Kblocks.dat

fio --name=random-write \
    --ioengine=posixaio \
    --rw=randwrite \
    --bs=64k \
    --size=256m \
    --numjobs=16 \
    --iodepth=16 \
    --runtime=60 \
    --time_based \
    --end_fsync=1 2>&1 > $ROOT/fs_randwrite_16job_256Mfs_64Kblocks.dat

rm random-write*
cat $ROOT/fs_randwrite_16job_256Mfs_64Kblocks.dat

fio --name=random-write \
    --ioengine=posixaio \
    --rw=randwrite \
    --bs=1m \
    --size=16g \
    --numjobs=1 \
    --iodepth=1 \
    --runtime=60 \
    --time_based \
    --end_fsync=1 2>&1 > $ROOT/fs_randwrite_1job_1Gfs_1Mblocks.dat

rm random-write*
cat $ROOT/fs_randwrite_1job_1Gfs_1Mblocks.dat

cd "$ROOT"