#!/bin/sh

. ./common

start_test "Run date"
date
result $? "RTC-date"

start_test "Run hwclock"
hwclock
result $? "RTC-hwclock"

start_test "Check dmesg logs"
dmesg |grep -i rtc
result 0 "rtc-dmesg"

