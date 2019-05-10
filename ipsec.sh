#!/bin/sh

. ./common

start_test "Check support of IPSEC"
# https://vincent.bernat.im/fr/blog/2017-vpn-ipsec-route
ip xfrm state
if [ $? -ne 0 ];then
	result SKIP "ipsec"
	exit 0
fi

ping -c4 ipsec.lava.local
if [ $? -ne 0 ];then
	result SKIP "ipsec"
	exit 0
fi

result SKIP "ipsec"
exit 0

dd if=/dev/urandom count=32 bs=1 2>/dev/null | xxd -p -c 64 > $OUTPUT_DIR/ipsec.key
if [ $? -ne 0 ];then
	result SKIP "ipsec generate key"
	exit 0
fi

if [ ! -s $OUTPUT_DIR/ipsec.key ];then
	result SKIP "ipsec generate key"
	exit 0
fi
