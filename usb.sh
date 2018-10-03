#!/bin/sh

. ./common

#try to load all USB modules
find /lib/modules -type f |grep kernel/drivers/usb | sed 's,.*/,,' |
while read usbmodule
do
	echo "DEBUG: module load $usbmodule"
	modprobe $usbmodule
	result $? "usbload-$usbmodule"
done

lsusb
result $? "lsusb"
