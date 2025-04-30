#!/bin/sh

. ./common

start_test "Run date"
date
result $? "RTC-date"

start_test "Run hwclock"
if [ "$IHAVE_HWCLOCK" = 'yes' ];then
	hwclock
	result $? "RTC-hwclock"
else
	result skip "RTC-hwclock"
fi

start_test "Check dmesg logs"
dmesg |grep -i rtc
result 0 "rtc-dmesg"

