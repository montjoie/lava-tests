#!/bin/sh

. ./common

start_test "Mount debugfs"
mount -t debugfs none /sys/kernel/debug
result $? "emce-mount-debugfs"

start_test "Read EMCE status"
cat /sys/kernel/debug/sun50i-emce/stats
result $? "emce-read"

start_test "Read MMC EMCE status"
cat /sys/kernel/debug/mmc-emce/stats
result $? "emce-mmc-read"

DEV=/dev/mmcblk1

if [ ! -e $DEV ];then
	echo "Missing $DEV"
	exit 0
fi
start_test "Dump initial"
hexdump -C -n 512 $DEV
result $? "emce-hexdump-initial"

start_test "Enable EMCE"
echo 1 > /sys/kernel/debug/sun50i-emce/control
result $? "emce-enable-emce"

start_test "Enable MMC EMCE"
echo 1 > /sys/kernel/debug/mmc-emce/control
result $? "emce-enable-mmc-emce"

start_test "Verify EMCE status"
cat /sys/kernel/debug/sun50i-emce/stats
result $? "emce-verify-emce"

start_test "Verify MMC EMCE status"
cat /sys/kernel/debug/mmc-emce/stats
result $? "emce-verify-mmc"

start_test "Dump before write"
hexdump -C -n 512 $DEV
result $? "emce-hexdump-before"

start_test "Write to device"
dd if=/dev/zero of=$DEV count=512
result $? "emce-write"

start_test "Dump after write"
hexdump -C -n 512 $DEV
result $? "emce-hexdump-after"



start_test "Disable MMC EMCE"
echo 0 > /sys/kernel/debug/mmc-emce/control
result $? "emce-disable-mmc-emce"

start_test "Disable EMCE"
echo 0 > /sys/kernel/debug/sun50i-emce/control
result $? "emce-disable-emce"

start_test "Dump final"
hexdump -C -n 512 $DEV
result $? "emce-hexdump-final"
