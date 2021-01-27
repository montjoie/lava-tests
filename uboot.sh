#!/bin/sh

. ./common

start_test "Get machine model"
get_machine_model
if [ -z "$MACHINE_MODEL_" ];then
	result FAIL get-machine-model
else
	echo "DEBUG: Run on $MACHINE_MODEL_"
	result 0 get-machine-model
fi

case $(uname -m) in
armv7l)
	if [ -z "$SOC" ];then
		echo "ERROR: SOC is unknow"
		exit 1
	fi
;;
aarch64)
	if [ -z "$SOC" ];then
		echo "ERROR: SOC is unknow"
		exit 1
	fi
;;
*)
	echo "ERROR: uboot not handled on x86"
	exit 1
;;
esac

BOOT_DEV=none
for block in $(ls /sys/block/ |grep mmc | grep -v boot |grep -v 'p[0-9]$')
do
	cblock=$(readlink /sys/block/$block | grep -o '/[0-9a-f]*.mmc/' | cut -d/ -f2)
	echo "==============================="
	echo "INFO: found $block from $cblock"
	case $SOC in
	H6)
		case $cblock in
		4020000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		4021000.mmc)
			echo "Controller is SDIO"
		;;
		4022000.mmc)
			echo "Controller is SMHC2 EMMC"
		;;
		*)
			echo "Unknown controller"
		esac
	;;
	a64)
		case $cblock in
		1c0f000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		1c10000.mmc)
			echo "Controller is SDIO"
		;;
		1c11000.mmc)
			echo "Controller is SMHC2 EMMC"
		;;
		*)
			echo "Unknown controller"
		esac
	;;
	a83t)
		case $cblock in
		1c0f000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		1c10000.mmc)
			echo "Controller is SDIO"
		;;
		1c11000.mmc)
			echo "Controller is SMHC2 EMMC"
		;;
		*)
			echo "Unknown controller"
		esac
	;;
	r40)
		case $cblock in
		1c0f000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		1c10000.mmc)
			echo "Controller is SDIO"
		;;
		1c11000.mmc)
			echo "Controller is SMHC2 EMMC"
		;;
		*)
			echo "Unknown controller"
		esac
	;;
	*)
		echo "ERROR: unknow SOC"
		exit 1
	;;
	esac
	echo "==============================="
done

if [ ! -e $BOOT_DEV ];then
	echo "ERROR: do not find boot device"
	exit 0
fi

if [ -z "$UBOOT_BIN_URL" ];then
	echo "INFO: UBOOT_BIN_URL default"
	UBOOT_BIN_URL=http://boot.montjoie.local/uboot/
fi

echo "Will install uboot in $BOOT_DEV"
wget $UBOOT_BIN_URL/uboot-$MACHINE_MODEL_
if [ $? -ne 0 ];then
	echo "ERROR: fail to download"
	exit 1
fi

case $SOC in
a64)
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV bs=8k seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash"
	fi
	sync
;;
a83t)
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV bs=8k seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash"
	fi
	sync
;;
r40)
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV bs=8k seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash"
	fi
	sync
;;
*)
	echo "Unknow way of flash"
	exit 1
;;
esac
