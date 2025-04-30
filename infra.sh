#!/bin/sh

. ./common

get_machine_model

TEST_PREFIX="test-network"

check_config IP_PNP_DHCP

start_test "Run ip"
ip a
result $? "ip"

start_test "Run ip route"
ip route
result $? "ip-route"

start_test "Test gateway"
GATEWAY_IP=$(ip route |grep ^default | cut -d' ' -f3)
if [ -z "$GATEWAY_IP" ];then
	echo "ERROR: no gateway"
	result SKIP "ping-gateway"
else
	echo "DEBUG: detected $GATEWAY_IP as gateway"
	ping -c 4 "$GATEWAY_IP"
	result $? "ping-gateway"
fi

grep nameserver /proc/net/pnp | cut -d' ' -f2 > "$OUTPUT_DIR/nameservers"
while read -r nameserver
do
	start_test "Test nameserver $nameserver"
	ping -c 4 "$nameserver"
	result $? "ping-nameserver-$nameserver"
done < "$OUTPUT_DIR/nameservers"

if [ ! -z "$GATEWAY_IP" ];then
	start_test "Test external network"
	ping -c 4 8.8.8.8
	result $? "external-network"

	start_test "Test DNS"
	ping -c 4 dns.google.com
	result $? "dns"
fi

TEST_PREFIX="infra"

if [ -e /sys/bus/usb ];then
	start_test "Test lsusb"
	lsusb
	result $? "lsusb"
fi

if [ -e /sys/bus/pci ];then
	start_test "Test lspci"
	lspci
	result $? "lspci"
fi

if [ "$IHAVE_SENSORS" = 'yes' ];then
	start_test "Run sensors"
	sensors
	result $? "sensors"
fi

#start_test "dmesg logs"
for level in warn err; do
	start_test "Check dmesg $level"
	ret=0
	dmesg --level=$level --notime -x -k |grep -v 'This is intended for developer use only' > dmesg.$level
	if [ -s dmesg.$level ];then
		ret=1
	fi
	result $ret "dmesg-$level"
	# now get reference
	start_test "dmesg-new-$level"
	wget -q https://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.$level
	if [ -e ${MACHINE_MODEL_}.$level ];then
		diff -u ${MACHINE_MODEL_}.$level dmesg-$level
		result $? "dmesg-new-$level"
	else
		result skip "dmesg-new-$level"
	fi
done
for level in crit alert emerg; do
	start_test "Check dmesg $level"
	ret=0
	dmesg --level=$level --notime -x -k > dmesg.$level
	test -s dmesg.$level && res=fail || res=pass
	count=$(cat dmesg.$level | wc -l)
	lava-test-case $level \
		--result $res \
		--measurement $count \
		--units lines
	if [ -s dmesg.$level ];then
		ret=1
	fi
	result $ret "dmesg-$level"
done

cat dmesg.emerg dmesg.alert dmesg.crit dmesg.err dmesg.warn


echo "DEBUG: check firmware"
ls -lR /lib/firmware

echo "DEBUG: check spi"
if [ -e /sys/bus/spi ];then
	ls /sys/bus/spi
	ls /sys/bus/spi/devices
fi

echo "DEBUG: check blocks"
fdisk -l
lsblk
if [ ! -z "$INEED_BLK" ];then
	start_test "Check block presence"
	ret=0
	for blk in $INEED_BLK
	do
		if [ -e $blk ];then
			echo "DEBUG: found $blk"
		else
			echo "DEBUG: did not found $blk"
			ret=1
		fi
	done
	result $ret "infra-blocks"
fi


echo "DEBUG: check bus presence"
ls /sys/bus

echo "DEBUG: driver dump"

ddump='/tmp/${MACHINE_MODEL_}.ddump'
echo "==DRIVER_DUMP=="
echo "==VERSION=3=="
echo "$MACHINE_MODEL_:" > $ddump
echo "  devices:" >> $ddump
for bus in $(ls /sys/bus)
do
	echo "    $bus:" >> $ddump
	find /sys/bus/$bus/devices -type l > /tmp/list
	if [ ! -s /tmp/list ];then
		continue
	fi
	while read line
	do
		device=$(basename "$line")
		echo "      - $device" >> $ddump
		if [ ! -e "$line/driver" ];then
			continue
		fi
		driverl=$(readlink "$line/driver")
		driver=$(basename "$driverl")
		echo "        driver: $driver" >> $ddump
		echo "        compatibles:" >> $ddump
		grep -q "^OF_COMPATIBLE_N" "$line/uevent"
		if [ $? -eq 0 ];then
			grep "OF_COMPATIBLE_[0-9]" "$line/uevent" | cut -d= -f2 |
			while read compatible
			do
				echo "          - $compatible" >> $ddump
			done
		fi
	done < /tmp/list
done
cat $ddump
echo "==DRIVER_DUMP_END=="

start_test "Compare driver dump"
wget https://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.txt
if [ $? -eq 0 ];then
	diff -u ${MACHINE_MODEL_}.txt $ddump
	result $? "driver-dump-diff"
else
	result skip "driver-dump-diff"
fi
