#!/bin/sh

. ./common

if [ ! -e /sys/class/mmc_host/ ];then
	result SKIP "mmc"
	exit 0
fi

fdisk -l |grep ^/
fdisk -l |grep ^/ | cut -d' ' -f1 > /tmp/mmclist
if [ -s /tmp/mmclist ];then
	while read tdev
	do
		start_test "Read $tdev via dd"
		dd if=$tdev of=/dev/null bs=1M count=50
		result $? "mmc-dd-$tdev"
	done < /tmp/mmclist
else
	result SKIP "mmc"
fi
exit 0

for mmchost in $(ls /sys/class/mmc_host/)
do
	echo "CHECK: $mmchost"
	#find block
	ls -l /sys/class/mmc_host/$mmchost/
	find /sys/class/mmc_host/$mmchost/
	#MMC_D=$(find /sys/class/mmc_host/$mmchost/ -iname "$mmchost:*")
	#echo "CHECK: $mmchost $MMC_D"
	#MMCBLOCK=$(ls /sys/class/mmc_host/$mmchost/$MMC_D/block/)
	#echo "CHECK: $mmchost $MMCDLOCK"
	#if [ -e /dev/$MMCBLOCK ];then
	#	fdisk -l /dev/$MMCBLOCK
	#fi
done
