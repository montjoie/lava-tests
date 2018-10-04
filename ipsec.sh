#!/bin/sh

. ./common

start_test "Check support of IPSEC"
# https://vincent.bernat.im/fr/blog/2017-vpn-ipsec-route
ip xfrm state
if [ $? -ne 0 ];then
	result SKIP "ipsec"
	exit 0
fi

