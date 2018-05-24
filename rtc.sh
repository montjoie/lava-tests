#!/bin/sh

. ./common

date
result $? "TEST_CASE_ID=date"

hwclock
result $? "TEST_CASE_ID=hwclock"

dmesg |grep rtc
result 0 "TEST_CASE_ID=dmesg-rtc"

