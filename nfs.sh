#!/bin/sh

. ./common

if [ -x mount.nfs ];then
	result SKIP "NFSmount"
	exit 0
fi

find |grep lockd

# TODO how to test
MNTPOINT=/tmp/test
mkdir -p $MNTPOINT

# mount
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 192.168.1.8:/var/tmp/lava-nfs/ $MNTPOINT
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
