#!/bin/sh

. ./common

date
result $? "date"

hwclock
result $? "hwclock"

dmesg |grep rtc
result 0 "dmesg-rtc"

