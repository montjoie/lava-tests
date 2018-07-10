#!/bin/sh

. ./common

if [ ! -e /sys/bus/pci ];then
	result SKIP "pci"
	exit 0
fi

lspci
result $? "lspci"
