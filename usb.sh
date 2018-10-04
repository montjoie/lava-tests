#!/bin/sh

. ./common

#try to load all USB modules
find /lib/modules -type f |grep kernel/drivers/usb | sed 's,.*/,,' |
while read usbmodule
do
	#echo "DEBUG: module load $usbmodule"
	start_test "Load $usbmodule"
	modprobe $usbmodule
	result $? "usb-load-$usbmodule"
done

start_test "Run lsusb"
lsusb
result $? "usb-lsusb"
