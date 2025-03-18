#!/bin/sh

. ./common

start_test "Detect RTC"
ls /sys/class/rtc/
result $? "test-detect-i2c-bus"

for rtc in $(ls /sys/class/rtc/)
do
	ls -l /sys/class/rtc/$rtc/
done


cat /sys/power/state

dmesg |grep console

ls /sys/class/tty
ls /sys/class/tty/ttyS0/
ls /sys/class/tty/ttyS0/power

echo enabled > /sys/class/tty/ttyS0/power/wakeup

echo +10 > /sys/class/rtc/rtc0/wakealarm

dmesg |tail
echo "SUSPEND"
echo mem > /sys/power/state


sleep 10
dmesg | tail -n 20
