#!/bin/sh

. ./common

check_config NVMEM
check_config EEPROM

start_test "Check presence of NVMEM or EEPROM"

find /sys/ -iname eeprom -type f
find /sys/ -iname nvmem -type f

find /sys/ -iname eeprom -type f |
while read -r eefile
do
	NAME=$(echo "$eefile" | sed 's,/eeprom$,,' | sed 's,.*/,,')
	start_test "Dump EEPROM $NAME"
	hexdump -C "$eefile"
	result $? "eeprom-$NAME"
done

find /sys/ -iname nvmem -type f |
while read -r nvmemfile
do
	NAME=$(echo "$nvmemfile" | sed 's,/nvmem$,,' | sed 's,.*/,,')
	start_test "Dump NVMEM $NAME"
	grep -qE 'QEMU-sparc64|EPBX100'  $OUTPUT_DIR/machinemodel
	RET=$?
	if [ $RET -eq 0 ];then
		echo "DEBUG: skip due to qemu crash"
		result SKIP "nvmem-$NAME"
		continue
	fi
	hexdump -C "$nvmemfile"
	result $? "nvmem-$NAME"
	# TODO sunxi-sid test of first values
done

start_test "decode-dimms"
if [ "$IHAVE_EEPROM" = 'yes' ];then
	decode-dimms
	result $? decode-dimms
else
	result skip decode-dimms
fi
