#!/bin/sh

. ./common

lsusb
result $? "TEST_CASE_ID=lsusb"
