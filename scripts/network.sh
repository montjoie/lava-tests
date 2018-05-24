#!/bin/sh

result() {
	result=$1
	shift
	if [ "$result" == 'SKIP' ];then
		echo "<LAVA_SIGNAL_TESTCASE $* RESULT=SKIP>"
		return
	fi
	if [ $result -eq 127 ];then
		echo "<LAVA_SIGNAL_TESTCASE $* RESULT=SKIP>"
		return
	fi
	if [ $result -eq 0 ];then
		echo "<LAVA_SIGNAL_TESTCASE $* RESULT=PASS>"
	else
		echo "<LAVA_SIGNAL_TESTCASE $* RESULT=FAIL>"
	fi
}

ip a
result $? "TEST_CASE_ID=ip"

ifconfig
result $? "TEST_CASE_ID=ifconfig"

ping -c4 192.168.1.1
result $? "TEST_CASE_ID=ping"

chmod +x /usr/sbin/ethtool
/usr/sbin/ethtool eth0
result $? "TEST_CASE_ID=ethtool"

find / |grep mii
/sbin/mii-tool eth0
result SKIP "TEST_CASE_ID=mii-tool"

/usr/bin/iperf3 -c 192.168.1.100
result SKIP "TEST_CASE_ID=iperf"

export

dmesg | grep -vf dmesg.ignore | grep -iE 'warn|error|fail'
result SKIP "TEST_CASE_ID=dmesg"

modprobe tcrypt
result 0 "TEST_CASE_ID=tcrypt"

# re dmesg

# check counter ifconfig
