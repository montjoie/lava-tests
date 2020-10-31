#!/bin/sh

. ./common

#try to load all wifi modules
find /lib/modules -type f |grep kernel/ | grep wireless | sed 's,.*/,,' |
while read -r wifi_module
do
	start_test "Load $wifi_module"
	modprobe "$wifi_module"
	result $? "wifi-load-$wifi_module"
done


echo "check regulatory.db"
find / |grep regulatory.db

start_test "Run iwconfig"
iwconfig
result $? "wifi-iwconfig"

start_test "check presence of wpa_suplicant"
find / |grep wpa
result $? "wifi-wpa"

test_wifi_interface() {
	netdev=$1
	start_test "Run iwlist scanning"
	iwlist $netdev scanning
	result $? "wifi-iwlist-scanning-$netdev"

	start_test "Run iwlist ap"
	iwlist $netdev ap
	result $? "wifi-iwlist-ap-$netdev"

	start_test "Run iwlist channel"
	iwlist $netdev channel
	result $? "wifi-iwlist-channel-$netdev"

}

for f in /sys/class/net/*
do
	iface=$(basename "$f")
	driverpath=$(readlink "$f/device/driver")
	driver=$(basename "$driverpath")
	if [ -z "$driver" ]; then
		echo "SKIP: dont check $iface with no driver"
	fi
	echo "DEBUG: Found interface $iface with driver=$driver"
	if [ "$iface" = 'lo' ];then
		echo "SKIP: dont check $iface"
		continue
	fi
	echo $iface |grep -q 'wlan'
	RET=$?
	if [ $RET -ne 0 ];then
		echo "SKIP: $iface is not a wireless interface"
		continue
	fi
	test_wifi_interface "$iface"
done
exit 0

