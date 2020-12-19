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

echo "================================="
fdisk -l
echo "================================="
lsblk
echo "================================="

EMCEDEV=none
for block in $(ls /sys/block/ |grep mmc | grep -v boot)
do
	cblock=$(readlink /sys/block/$block | grep -o '/[0-9a-f]*.mmc/' | cut -d/ -f2)
	echo "INFO: found $block from $cblock"
	case $cblock in
	4020000.mmc)
		echo "Controller is SD"
	;;
	4021000.mmc)
		echo "Controller is SDIO"
	;;
	4022000.mmc)
		echo "Controller is SMHC2 EMMC"
		EMCEDEV=/dev/$block
	;;
	*)
		echo "Unknown controller"
	esac
done


if [ ! -e $EMCEDEV ];then
	echo "Missing SMHC2 controller with emmc"
	exit 0
fi

start_test "Dump initial $EMCEDEV"
hexdump -C -n 512 $EMCEDEV
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
try_run -t 20 hexdump -C -n 512 $EMCEDEV
result $? "emce-hexdump-before"

#start_test "Write to device"
#dd if=/dev/zero of=$EMCEDEV count=512
#result $? "emce-write"

start_test "Dump after write"
try_run -t 20 hexdump -C -n 512 $EMCEDEV
result $? "emce-hexdump-after"

start_test "Disable MMC EMCE"
echo 0 > /sys/kernel/debug/mmc-emce/control
result $? "emce-disable-mmc-emce"

start_test "Disable EMCE"
echo 0 > /sys/kernel/debug/sun50i-emce/control
result $? "emce-disable-emce"

start_test "Dump final"
try_run -t 20 hexdump -C -n 512 $EMCEDEV
result $? "emce-hexdump-final"
