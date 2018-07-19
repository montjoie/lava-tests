#!/bin/sh

. ./common

echo "check regulatory.db"
find / |grep regulatory.db

iwconfig

echo "Check iwlist"
iwlist

echo "check wpa"
find / |grep wpa

exit 0

iwconfig
result $? "iwconfig"

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

# re dmesg

# check counter ifconfig
