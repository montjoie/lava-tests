#!/bin/sh

. ./common

if [ ! -e /sys/class/i2c-adapter/ ];then
	#result SKIP "i2c"
	#exit 0
	echo "DEBUG: no i2c adapter found"
	ls /sys/class
fi

start_test "Detect I2C bus"
i2cdetect -l | tee "$OUTPUT_DIR/i2c.list"
result $? "test-detect-i2c-bus"

grep -o '^i2c-[0-9][0-9]*' "$OUTPUT_DIR/i2c.list" | grep -o '[0-9]*$' | sort | uniq |
while read -r i
do
	start_test "Display capabilities of I2C bus $i"
	i2cdetect -F "$i"
	result $? "test-i2c-caps-$i"

	start_test "Dump I2C bus $i"
	i2cdetect -y "$i" | tee "$OUTPUT_DIR/i2c-${i}.dump"
	result $? "test-i2c-dump-$i"

	i2cdetect -y "$i" | grep '^[0-9]' | cut -d' ' -f2- |grep -o '[0-9][0-9a-f]' |
	while read -r address
	do
		start_test "Dump I2C bus $i address $address"
		echo "DEBUG: try address $address"
		i2cget -f -y "$i" "0x$address" 0
		result $? "test-i2c-get-$i-$address"
		start_test "Dump I2C bus $i address $address"
		i2cget -f -y "$i" "0x$address" $i
		result $? "test-i2c-get-$i-$address"
	done
done
