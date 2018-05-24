#!/bin/sh

. ./common

if [ -x mount.nfs ];then
	result SKIP "TEST_CASE_ID=NFSmount"
	exit 0
fi

find |grep lockd

# TODO how to test
MNTPOINT=/tmp/test
mkdir -p $MNTPOINT

# mount
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 192.168.1.100:/tmp/lava-test/ $MNTPOINT
RET=$?
result $RET "TEST_CASE_ID=NFSmount"
if [ $RET -ne 0 ];then
	exit 0
fi

touch $MNTPOINT/test
result $? "TEST_CASE_ID=NFStouch"

mkdir -p $MNTPOINT/testdir
result $? "TEST_CASE_ID=NFSmkdir"

# iozone

# umount
umount $MNTPOINT
result $? "TEST_CASE_ID=NFSumount"
