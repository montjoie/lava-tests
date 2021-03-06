#!/bin/sh

. ./common

if [ -x mount.nfs ];then
	result SKIP "NFSmount"
	exit 0
fi

start_test "Check presence of a NFS server to use"
# we need a NFS serser
ping -c4 nfs.lava.local
if [ $? -ne 0 ];then
	result SKIP "NFSmount"
	exit 0
fi

find |grep lockd

# TODO how to test
MNTPOINT=/tmp/test
mkdir -p $MNTPOINT

# mount
mount -t nfs -o rw,tcp,hard,intr,async,vers=3,timeo=2,retrans=2 nfs.lava.local:/var/tmp/lava-nfs/ $MNTPOINT
RET=$?
result $RET "NFSmount"
if [ $RET -ne 0 ];then
	exit 0
fi

touch $MNTPOINT/test
result $? "NFStouch"

mkdir -p $MNTPOINT/testdir
result $? "NFSmkdir"

# iozone

# umount
umount $MNTPOINT
result $? "NFSumount"
