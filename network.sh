#!/bin/sh

. ./common

ip a
result $? "ip"

ifconfig
result $? "ifconfig"

is_network_v4_ok
if [ $? -eq 0 ];then
	ping -c4 192.168.1.1
	result $? "ping"
else
	result SKIP "ping"
fi

chmod +x /usr/sbin/ethtool
/usr/sbin/ethtool eth0
result $? "ethtool"

find / |grep mii
/sbin/mii-tool eth0
result SKIP "mii-tool"

is_network_v4_ok
if [ $? -eq 0 ];then
	/usr/bin/iperf3 -c 192.168.1.100
	result SKIP "iperf"
else
	result SKIP "iperf"
fi

dmesg | grep -vf dmesg.ignore | grep -iE 'warn|error|fail'
result SKIP "dmesg"

# re dmesg

# check counter ifconfig
