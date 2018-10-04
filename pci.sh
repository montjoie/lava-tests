#!/bin/sh

. ./common

start_test "Check presence of PCI devices"
if [ ! -e /sys/bus/pci ];then
	result SKIP "pci"
	exit 0
fi

start_test "Run lspci"
lspci
result $? "lspci"
