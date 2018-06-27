#!/bin/sh

. ./common

if [ ! -e /sys/bus/pci ];then
	result SKIP "test_luks"
	exit 0
fi

cryptsetup --version
if [ $? -ne 0 ];then
	result SKIP "test_luks"
	exit 0
fi

# create a fake volume
dd if=/dev/zero of=fake.imd
result $? "test_luks_generate_img"
