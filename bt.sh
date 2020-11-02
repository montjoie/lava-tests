#!/bin/sh

. ./common

#try to load all wifi modules
find /lib/modules -type f |grep kernel/ | grep bluetooth | sed 's,.*/,,' |
while read -r bt_module
do
	start_test "Load $bt_module"
	modprobe "$bt_module"
	result $? "bt-load-$bt_module"
done

check_config BT || echo "DEBUG: Missing CONFIG_BT"

#bluetoothctl could not work without dbus and bluetoothd running
ps aux | grep -v 'grep' > "$OUTPUT_DIR/pslist"

start_test "Check if dbus is running"
grep -q 'dbus-daemon' "$OUTPUT_DIR/pslist"
RET=$?
if [ $RET -ne 0 ];then
	echo "Missing dbus"
	/etc/init.d/S30dbus start || exit $?
else
	echo "dbus is running"
fi
result 0 "bt-dbus-run"

start_test "Check if bluetoothd is running"
grep -q 'bluetoothd' "$OUTPUT_DIR/pslist"
RET=$?
if [ $RET -ne 0 ];then
	echo "Missing bluetoothd"
	/usr/libexec/bluetooth/bluetoothd &
	PID=$!
	echo "Started bluetoothd as $PID"
else
	echo "bluetoothd is running"
fi
result 0 "bt-bluetoothd-run"

start_test "Run bluetoothctl list"
bluetoothctl list
result $? "bt-bluetoothctl-list"

start_test "Run bluetoothctl show"
bluetoothctl show
result $? "bt-bluetoothctl-show"

start_test "Run bluetoothctl power on"
bluetoothctl power on
result $? "bt-bluetoothctl-power-on"

start_test "Run bluetoothctl scan on"
bluetoothctl scan on
result $? "bt-bluetoothctl-scan-on"

start_test "Run bluetoothctl devices"
bluetoothctl devices
result $? "bt-bluetoothctl-devices"

ls /sys/class/net

exit 0
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

