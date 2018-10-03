#!/bin/sh

. ./common

modprobe tcrypt
if [ $? -eq 1 ];then
	result SKIP "tcrypt"
else
	result 0 "tcrypt"
fi

# re dmesg

