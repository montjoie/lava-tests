#!/bin/sh

. ./common

check_config NVMEM
check_config EEPROM

start_test "Check presence of NVMEM or EEPROM"

find /sys/ -iname eeprom -type f
find /sys/ -iname nvmem -type f

find /sys/ -iname eeprom -type f |
while read eefile
do
	NAME=$(echo $eefile | sed 's,/eeprom$,,' | sed 's,.*/,,')
	start_test "Dump EEPROM $NAME"
	hexdump -C $eefile
	result $? "eeprom-$NAME"
done

find /sys/ -iname nvmem -type f |
while read nvmemfile
do
	NAME=$(echo $nvmemfile | sed 's,/nvmem$,,' | sed 's,.*/,,')
	start_test "Dump NVMEM $NAME"
	hexdump -C $nvmemfile
	result $? "nvmem-$NAME"
	# TODO sunxi-sid test of first values
done

# TODO decode-dimms
