#!/bin/sh

grep -q ' nfs ' /proc/mounts
if [ $? -eq 0 ];then
	echo "DEBUG: nfs detected, skipping ipsec test"
	exit 0
fi

SRC=192.168.1.0/24
DST=iperf.lava.local
LOCAL=10.7.0.2
REMOTE=10.7.0.1

if [ "$1" == 'server' ] ;then
	ID=$(cat keys/ipsec.id)
	KEY1=$(cat keys/ipsec1.key)
	KEY2=$(cat keys/ipsec2.key)
	# step to do on LAVA server
	ip xfrm state add src $SRC dst $DST proto esp spi $ID reqid $ID mode tunnel auth sha256 $KEY1 enc aes $KEY2
	ip xfrm state add src $DST dst $SRC proto esp spi $ID reqid $ID mode tunnel auth sha256 $KEY1 enc aes $KEY2
	ip xfrm policy add src $REMOTE dst $LOCAL dir out tmpl src $DST dst $SRC proto esp reqid $ID mode tunnel
	ip xfrm policy add src $LOCAL dst $REMOTE dir in tmpl src $SRC dst $DST proto esp reqid $ID mode tunnel
	ip addr add $REMOTE dev lo
	ip route add $LOCAL dev eth1 src $REMOTE
	exit 0
fi

. ./common

start_test "Check support of IPSEC"
# https://vincent.bernat.im/fr/blog/2017-vpn-ipsec-route
# https://gist.github.com/vishvananda/7094676
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

ID=$(cat keys/ipsec.id)
KEY1=$(cat keys/ipsec1.key)
KEY2=$(cat keys/ipsec2.key)
ip xfrm state flush

ip xfrm state add src $SRC dst $DST proto esp spi $ID reqid $ID mode tunnel auth sha256 $KEY1 enc aes $KEY2
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi
ip xfrm state add src $DST dst $SRC proto esp spi $ID reqid $ID mode tunnel auth sha256 $KEY1 enc aes $KEY2
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi
ip xfrm policy add src $LOCAL dst $REMOTE dir out tmpl src $SRC dst $DST proto esp reqid $ID mode tunnel
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi
ip xfrm policy add src $REMOTE dst $LOCAL dir in tmpl src $DST dst $SRC proto esp reqid $ID mode tunnel
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi
ip addr add $LOCAL dev lo
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi
ip route add $REMOTE dev eth1 src $LOCAL
if [ $? -ne 0 ];then
	result FAIL "ipsec"
	exit 0
fi

