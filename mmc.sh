#!/bin/sh

. ./common

if [ ! -e /sys/class/mmc_host/ ];then
	result SKIP "mmc"
	exit 0
fi

for mmchost in $(ls /sys/class/mmc_host/)
do
	#find block
	MMC_D=$(find /sys/class/mmc_host/$mmchost/ -iname "$mmchost:*")
	MMCBLOCK=$(ls /sys/class/mmc_host/$mmchost/$MMC_D/block/)
	if [ -e /dev/$MMCBLOCK ];then
		fdisk -l /dev/$MMCBLOCK
	fi
done
