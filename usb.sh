#!/bin/sh

. ./common

lsusb
result $? "lsusb"
