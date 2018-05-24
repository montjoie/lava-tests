#!/bin/sh

. ./common

if [ ! -e /sys/bus/pci ];then
	result SKIP "TEST_CASE_ID=pci"
	exit 0
fi

lspci
result $? "TEST_CASE_ID=lspci"
