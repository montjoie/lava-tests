#!/bin/sh

BOOT_DEVTYPE="sd"
NOACT=0
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
	-n)
		shift
		NOACT=1
	;;
	--nand)
		BOOT_DEVTYPE="nand"
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
		echo "ERROR: unknow SOC $SOC for MTD"
	;;
	esac

done

set_boot_dev() {
	echo "DEBUG: set_boot_dev $1 BOOT_DEVTYPE=$BOOT_DEVTYPE with dev=$2"
	if [ "$BOOT_DEVTYPE" == "$1" ];then
		BOOT_DEV="$2"
	fi
}

echo "DEBUG: content of /sys/block"
ls -l /sys/block/

FLASH_METHOD=""
BOOT_DEV=none
for block in $(ls /sys/block/ |grep mmc | grep -v boot |grep -v 'p[0-9]$')
do
	cblock=$(readlink /sys/block/$block | grep -oE '/[0-9a-f]*.mmc/|/[0-9a-f]*.sd/' | cut -d/ -f2)
	if [ -z "$cblock" ];then
		echo "DEBUG: empty cblock"
		ls -l /sys/block/
		readlink /sys/block/$block
	fi
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
	s805x)
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
	g12a)
		FLASH_METHOD="amlogic"
		case $cblock in
		ffe05000.sd)
			echo "Controller is SD"
			set_boot_dev sd /dev/$block
		;;
		ffe07000.mmc)
			echo "Controller is NAND"
			set_boot_dev nand /dev/$block
		;;
		*)
			echo "Unknown controller $cblock"
		;;
		esac
	;;
	g12b)
		FLASH_METHOD="amlogic"
		case $cblock in
		ffe05000.sd)
			echo "Controller is SD"
			set_boot_dev sd /dev/$block
		;;
		ffe07000.mmc)
			echo "Controller is NAND"
			set_boot_dev nand /dev/$block
		;;
		*)
			echo "Unknown controller $cblock"
		;;
		esac
	;;
	gxbb)
		FLASH_METHOD="amlogic2"
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
	sm1)
		FLASH_METHOD="amlogic"
		case $cblock in
		ffe05000.sd)
			echo "Controller is SD"
			set_boot_dev sd /dev/$block
		;;
		ffe07000.mmc)
			echo "Controller is NAND"
			set_boot_dev nand /dev/$block
		;;
		*)
			echo "Unknown controller $cblock"
		;;
		esac
	;;
	*)
		echo "ERROR: unknow SOC $SOC for SD"
		exit 1
	;;
	esac
	echo "==============================="
done

if [ ! -e $BOOT_DEV ];then
	echo "ERROR: do not find boot device"
	ls /sys/block/
	fdisk -l
	exit 0
fi

# armbian flash
if [ ! -z "$OS_IMAGE_URL" ];then
	#fdisk -l
	#mkdir /armbian
	#mount ${BOOT_DEV}p1 /armbian
	#touch /armbian/root/.not_logged_in_yet
	#touch /armbian/root/.not_logged_in
	#ls -l /armbian/
	#ls -la /armbian/root/
	#grep -ri not_logged_in /armbian/etc/
	#umount /armbian
	#sync
	#exit 0
	echo "DEBUG: downloading $OS_IMAGE_URL"
	OPWD=$(pwd)
	cd /tmp/
	wget -q --no-check-certificate "$OS_IMAGE_URL"
	if [ $? -ne 0 ];then
		echo "ERROR: fail to wget"
		exit 1
	fi

	IMAGE=$(ls |grep Armbian)
	if [ -z "$IMAGE" ];then
		echo "ERROR: could not find IMAGE"
		exit 1
	fi
	sha256sum $IMAGE
	ls -lh
	ls -l
	df -h
	echo "DEBUG: try to download sha256"
	wget -q --no-check-certificate "${OS_IMAGE_URL}.sha"
	if [ $? -ne 0 ];then
		echo "ERROR: fail to wget sha"
	fi
	if [ -e $IMAGE.sha ];then
		sha256sum -c $IMAGE.sha
		if [ $? -ne 0 ];then
			echo "ERROR: sha256sum is bad"
			exit 1
		fi
	fi

	echo $IMAGE |grep xz
	if [ $? -eq 0 ];then
		echo "DEBUG: $IMAGE is xz compressed"
		xzcat -V
	fi
	if [ $NOACT -eq 1 ];then
		BOOT_DEV="/dev/null"
	fi
	echo "DEBUG: will flash via xzcat $IMAGE > $BOOT_DEV"
	xzcat $IMAGE > $BOOT_DEV
	exit $?
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
amlogic)
	if [ $NOACT -eq 1 ];then
		BOOT_DEV="/dev/null"
	fi
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV conv=fsync,notrunc bs=512 skip=1 seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash to $BOOT_DEV"
	fi
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV conv=fsync,notrunc bs=1 count=444
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash to $BOOT_DEV"
	fi
	sync
;;
amlogic2)
	if [ $NOACT -eq 1 ];then
		BOOT_DEV="/dev/null"
	fi
	dd if=uboot-$MACHINE_MODEL_ of=$BOOT_DEV conv=fsync,notrunc bs=512 seek=1
	if [ $? -ne 0 ];then
		echo "ERROR: uboot flash to $BOOT_DEV"
	fi
	sync
;;
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
