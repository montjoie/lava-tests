#!/bin/sh

while [ $# -ge 1 ]
do
	case $1 in
	--uboot)
		shift
		if [ "$1" != 'unset' ];then
			UBOOT_BIN_URL="$1"
			echo "DEBUG: UBOOT IMAGE TO FLASH $UBOOT_BIN_URL"
		fi
		shift
	;;
	--osimage)
		shift
		if [ "$1" != 'unset' ];then
			OS_IMAGE_URL="$1"
			echo "DEBUG: OS IMAGE TO FLASH $OS_IMAGE_URL"
		fi
		shift
	;;
	*)
		echo "ERROR: unknow argument $1"
		exit 1
	;;
	esac
done

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
arc)
	mkdir -p /mnt/hsdk || exit $?
	wget $UBOOT_BIN_URL/u-boot-update.scr || exit $?
	wget $UBOOT_BIN_URL/u-boot.head || exit $?
	mount /dev/mmcblk0p1 /mnt/hsdk || exit $?
	mv u-boot.head /mnt/hsdk/ || exit $?
	mv u-boot-update.scr /mnt/hsdk/ || exit $?
	umount /mnt/hsdk
	sync
	exit 0
;;
*)
	echo "ERROR: uboot not handled on $(uname -m)"
	exit 1
;;
esac

NAND_DEV=""
echo "DEBUG: enumerate mtd devices"
cat /proc/mtd
for block in $(ls /sys/block/ |grep mtd |grep -v 'p[0-9]$')
do
	cblock=$(readlink /sys/block/$block | grep -o '/[0-9a-f]*.spi/' | cut -d/ -f2)
	echo "==============================="
	echo "INFO: found $block from $cblock"
	case $SOC in
	rk3328)
		case $cblock in
		ff190000.spi)
			echo "Controller is NAND"
			NAND_DEV="$cblock"
		;;
		*)
			echo "Unknown controller"
			ls -l /sys/block/$block
			readlink /sys/block/$block
		;;
		esac
	;;
	*)
		echo "ERROR: unknow SOC $SOC"
	;;
	esac

done

FLASH_METHOD=""
BOOT_DEV=none
for block in $(ls /sys/block/ |grep mmc | grep -v boot |grep -v 'p[0-9]$')
do
	cblock=$(readlink /sys/block/$block | grep -o '/[0-9a-f]*.mmc/' | cut -d/ -f2)
	echo "==============================="
	echo "INFO: found $block from $cblock"
	case $SOC in
	H6)
		FLASH_METHOD="sunxi"
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
	a20)
		FLASH_METHOD="sunxi"
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
	a64)
		FLASH_METHOD="sunxi"
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
		FLASH_METHOD="sunxi"
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
	H2plus)
		FLASH_METHOD="sunxi"
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
	h3)
		FLASH_METHOD="sunxi"
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
	H5)
		FLASH_METHOD="sunxi"
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
		FLASH_METHOD="sunxi"
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
	rk3328)
		FLASH_METHOD="rk3328"
		case $cblock in
		ff500000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		*)
			echo "Unknown controller $cblock"
		esac
	;;
	s905x)
		FLASH_METHOD="amlogic"
		case $cblock in
		d0072000.mmc)
			echo "Controller is SD"
			BOOT_DEV=/dev/$block
		;;
		d0074000.mmc)
			echo "Controller is SDIO"
		;;
		*)
			echo "Unknown controller $cblock"
		;;
		esac
	;;
	*)
		echo "ERROR: unknow SOC $SOC"
		exit 1
	;;
	esac
	echo "==============================="
done

if [ ! -e $BOOT_DEV ];then
	echo "ERROR: do not find boot device"
	exit 0
fi

# armbian flash
if [ ! -z "$OS_IMAGE_URL" ];then
	wget "$OS_IMAGE_URL"
	IMAGE=$(ls |grep Armbian)
	xzcat -V
	echo "DEBUG: will flash via xzcat $IMAGE > $BOOT_DEV"
	exit 0
fi

if [ -z "$UBOOT_BIN_URL" ];then
	echo "INFO: UBOOT_BIN_URL default"
	UBOOT_BIN_URL=http://boot.montjoie.local/uboot/
else
	echo "DEBUG: UBOOT_BIN_URL is $UBOOT_BIN_URL"
fi

mini_network_test
echo "Will install uboot in $BOOT_DEV"

echo "DEBUG: download uboot-$MACHINE_MODEL_"
wget $UBOOT_BIN_URL/uboot-$MACHINE_MODEL_
if [ $? -ne 0 ];then
	echo "ERROR: fail to download"
	exit 1
fi

# print version
grep -iao 'U-Boot[[:space:]]*[0-9][0-9]*.[0-9a-z.-]*[[:space:]]*([^)]*)' uboot-$MACHINE_MODEL_

case $FLASH_METHOD in
sunxi)
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV bs=8k seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash"
	fi
	sync
;;
rk3328)
	# Need additional idbloater
	echo "DEBUG: download ${MACHINE_MODEL_}-idbloader.img"
	wget $UBOOT_BIN_URL/${MACHINE_MODEL_}-idbloader.img
	if [ $? -ne 0 ];then
		echo "ERROR: fail to download"
		exit 1
	fi
	dd if=${MACHINE_MODEL_}-idbloader.img of=$BOOT_DEV seek=64
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash"
	fi
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV seek=16384
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
