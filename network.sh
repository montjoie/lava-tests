#!/bin/sh

. ./common

ip a
result $? "ip"

ifconfig
result $? "ifconfig"

ping -c4 192.168.1.1
result $? "ping"

chmod +x /usr/sbin/ethtool
/usr/sbin/ethtool eth0
result $? "ethtool"

find / |grep mii
/sbin/mii-tool eth0
result SKIP "mii-tool"

/usr/bin/iperf3 -c 192.168.1.100
result SKIP "iperf"

dmesg | grep -vf dmesg.ignore | grep -iE 'warn|error|fail'
result SKIP "dmesg"

modprobe tcrypt
if [ $? -eq 1 ];then
	result SKIP "tcrypt"
else
	result 0 "tcrypt"
fi

# re dmesg

# check counter ifconfig
