#!/bin/sh

. ./common

ls /sys/class/hwmon/ > /sensor.list
if [ ! -s /sensor.list ];then
	result SKIP "sensor"
	exit 0
fi

start_test "Run sensor"
sensors
result $? "sensor"
