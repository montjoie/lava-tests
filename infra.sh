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

if [ ! -e /etc/resolv.conf ];then
	echo "DEBUG: get namserver from Linux IP PNP"
	grep nameserver /proc/net/pnp > /etc/resolv.conf
fi

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
	if [ "$IHAVE_USB" = 'yes' ];then
		lsusb
		result $? "lsusb"
	else
		result skip lsusb
	fi
fi

if [ -e /sys/bus/pci ];then
	start_test "Test lspci"
	lspci
	result $? "lspci"
	lspci -kvx
fi

if [ -e /lib/modules4 ];then
	HWMON_PROBLEM=0
	case $(uname -m) in
	aarch64)
		HWMON_PROBLEM=1
	;;
	armel)
		HWMON_PROBLEM=1
	;;
	armv7l)
		HWMON_PROBLEM=1
	;;
	riscv64)
		HWMON_PROBLEM=1
	;;
	esac
	# try to load all sensors modules
	find /lib/modules -type f |grep kernel/drivers/hwmon | sed 's,.*/,,' > /tmp/hwmon.list
	while read -r hwmon_module
	do
		start_test "Load $hwmon_module"
		if [ $HWMON_PROBLEM -eq 1 ];then
			echo $hwmon_module | grep -qE 'w836|f71882fg|it87|vt1211|smsc47b397|pc87360|smsc47m1|f71805f|sch5627|sch56xx-common|pc87427|sm4_generic|sch5636|nct6683|dme1737'
			if [ $? -eq 0 ];then
				result skip "${TEST_PREFIX}load-$hwmon_module"
				continue
			fi
		fi
		modprobe "$hwmon_module" |tee modprobe.out 2>&1
		RET=$?
		grep -q 'No such device' modprobe.out
		if [ $? -eq 0 ];then
			RET=0
		fi
		result $? "${TEST_PREFIX}load-$hwmon_module"
	done < /tmp/hwmon.list
else
	result SKIP "hwmon-load-all-modules"
fi

if [ "$IHAVE_SENSORS" = 'yes' ];then
	start_test "Run sensors"
	sensors
	result $? "sensors"
else
	echo "DEBUG: no sensors on this platform"
fi

#start_test "dmesg logs"
for level in warn err; do
	start_test "Check dmesg $level"
	ret=0
	dmesg --level=$level --notime -x -k |grep -v 'This is intended for developer use only' > dmesg.$level
	if [ -s dmesg.$level ];then
		ret=1
	fi
	# now get reference
	wget -q https://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.$level
	if [ -e ${MACHINE_MODEL_}.$level ];then
		result skip "dmesg-$level"
		start_test "dmesg-new-$level"
		# some pattern hack
		sed -i 's,lava-[0-9]*,lava-xxx,' dmesg.$level
		sed -i 's,lava-[0-9]*,lava-xxx,' ${MACHINE_MODEL_}.$level
		grep -vEf dmesg.ignore dmesg.$level > dmesgf.$level
		diff -u ${MACHINE_MODEL_}.$level dmesgf.$level | tee dmesg.diff
		RET=$?
		echo "DEBUG: diff ret=$RET"
		grep -q '^+' dmesg.diff
		result $? "dmesg-new-$level"
	else
		result $ret "dmesg-$level"
		start_test "dmesg-new-$level"
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


#echo "DEBUG: check firmware"
#ls -lR /lib/firmware

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

ddump="/tmp/${MACHINE_MODEL_}.ddump"
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
		echo "      - $device:" >> $ddump
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
sleep 2
sync

start_test "Compare driver dump"
wget https://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.txt
if [ $? -eq 0 ];then
	diff -u ${MACHINE_MODEL_}.txt $ddump
	result $? "driver-dump-diff"
else
	result skip "driver-dump-diff"
fi

echo "DEBUG: check devfreq"
for cpu in $(ls /sys/devices/system/cpu/ |grep 'cpu[0-9]')
do
	if [ -e /sys/devices/system/cpu/$cpu/cpufreq/ ];then
		echo "CPU $cpu"
		ls -l /sys/devices/system/cpu/$cpu/
		echo "CPU $cpu cpufreq"
		ls -l /sys/devices/system/cpu/$cpu/cpufreq/
		echo "CPU $cpu cpufreq scaling_available_governors"
		cat /sys/devices/system/cpu/$cpu/cpufreq/scaling_available_governors
		echo "CPU $cpu cpufreq scaling_cur_freq"
		cat /sys/devices/system/cpu/$cpu/cpufreq/scaling_cur_freq
		echo "CPU $cpu cpufreq min"
		cat /sys/devices/system/cpu/$cpu/cpufreq/cpuinfo_min_freq
		echo "CPU $cpu cpufreq max"
		cat /sys/devices/system/cpu/$cpu/cpufreq/cpuinfo_max_freq
	fi
done

for cpu in $(ls /sys/devices/system/cpu/ |grep 'cpu[0-9]')
do
	if [ -e /sys/devices/system/cpu/$cpu/cpufreq/ ];then
		governor_orig=$(cat /sys/devices/system/cpu/$cpu/cpufreq/scaling_governor)
		echo "DEBUG: original governor: $governor_orig"
		for governor in $(cat /sys/devices/system/cpu/$cpu/cpufreq/scaling_available_governors)
		do
			start_test "Try devfreq $governor"
			echo $governor > /sys/devices/system/cpu/$cpu/cpufreq/scaling_governor
			result $? "devfreq-$cpu-$governor"
		done
		echo $governor_orig > /sys/devices/system/cpu/$cpu/cpufreq/scaling_governor
	fi
done

if [ -e /lib/modules4 ];then
	HWMON_PROBLEM=0
	case $(uname -m) in
	aarch64)
		HWMON_PROBLEM=1
	;;
	armel)
		HWMON_PROBLEM=1
	;;
	armv7l)
		HWMON_PROBLEM=1
	;;
	riscv64)
		HWMON_PROBLEM=1
	;;
	esac
	# try to load all sensors modules
	find /lib/modules -type f |grep kernel/ | sed 's,.*/,,' > /tmp/modules.list
	while read -r modules_module
	do
		start_test "Load module $modules_module"
		if [ $HWMON_PROBLEM -eq 1 ];then
			echo $modules_module | grep -qE 'w836|f71882fg|it87|vt1211|smsc47b397|pc87360|smsc47m1|f71805f|sch5627|sch56xx-common|pc87427|sm4_generic|sch5636|nct6683|dme1737'
			if [ $? -eq 0 ];then
				result skip "${TEST_PREFIX}load-$modules_module"
				continue
			fi
		fi
		modprobe "$modules_module" |tee modprobe.out 2>&1
		RET=$?
		grep -q 'No such device' modprobe.out
		if [ $? -eq 0 ];then
			RET=0
		fi
		result $? "${TEST_PREFIX}load-$modules_module"
	done < /tmp/modules.list
else
	result SKIP "modules-load-all-modules"
fi
