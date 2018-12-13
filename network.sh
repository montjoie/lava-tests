#!/bin/sh

. ./common

get_machine_model

HAVE_ETHTOOL=0
INTERFACE=eth0
TEST_PREFIX="test-network"
NBD_ROOT=0

grep -i nbd /proc/mounts
if [ $? -eq 0 ];then
	NBD_ROOT=1
fi

start_test "Run ip"
ip a
result $? "ip"

start_test "Run ifconfig"
ifconfig
result $? "ifconfig"

start_test "Run ip route"
ip route
result $? "ip-route"

start_test "Test gateway"
GATEWAY_IP=$(ip route |grep ^default | cut -d' ' -f3)
ping -c4 $GATEWAY_IP
result $? "ping-gateway"

start_test "Test external network"
ping -c4 8.8.8.8
result $? "external-network"

start_test "Test DNS"
ping -c4 storage.kernelci.org
result $? "dns"

# test an ethtool command
# arg1: return code for not supported (see ethtool code source)
# arg2: summary of the command
# arg3: command to execute
kci_netdev_ethtool_test()
{
	if [ $# -le 2 ];then
		echo "SKIP: $netdev: ethtool: invalid number of arguments"
		return 1
	fi
	start_test "Test ethtool $2 on $4"
	echo "DEBUG: run $3"
	$3 >/dev/null
	ret=$?
	if [ $ret -ne 0 ];then
		if [ $ret -eq "$1" ];then
			#echo "SKIP: $netdev: ethtool $2 not supported"
			result SKIP --sleep 3 "network-$netdev-ethtool-$2"
			return 0
		else
			#echo "FAIL: $netdev: ethtool $2"
			result 1 --sleep 3 "network-$netdev-ethtool-$2"
			return 0
		fi
	else
		result 0 --sleep 3 "network-$netdev-ethtool-$2"
	fi
	return 0
}


test_interface() {
	if [ -z "$1" ];then
		echo "ERROR: Missing argument to test_interface()"
		return 1
	fi
	netdev="$1"
	echo "DEBUG: test_interface $1"

	start_test "Get features list from $1"
	ethtool -k $1
	result $? "network-$1-ethtool-features-list"

	kci_netdev_ethtool_test 74 'dump' "ethtool -d $netdev" "$netdev"
	kci_netdev_ethtool_test 94 'stats' "ethtool -S $netdev" "$netdev"

	start_test "Detect if $1 have an IP"
	ip address show dev $1 |grep -q 'inet[[:space:]]'
	if [ $? -ne 0 ];then
		echo "DEBUG: $1 have no IP"
		return 0
	fi

	start_test "Detect if $1 have a gateway"
	#try to find something to ping
	GATEWAY=$(ip route |grep ^default | cut -d' ' -f3)
	if [ -z "$GATEWAY" ];then
		result SKIP "network-$1-ping-gateway"
	else
		echo "DEBUG: Found gateway $GATEWAY"
		start_test "ping the gateway"
		ping -c4 $GATEWAY
		result $? "network-$1-ping-gateway"
	fi

}

# compare current ethtool output with a reference one
compare_ethtool() {
	/usr/sbin/ethtool eth0 > $OUTPUT_DIR/ethtool.raw
	RET=$?
	if [ $RET -ne 0 ];then
		echo "DEBUG: Should not fail"
		return $RET
	fi
	wget http://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.ethtool
	RET=$?
	if [ $RET -ne 0 ];then
		echo "DEBUG: Cannot get reference ethtool for ${MACHINE_MODEL_}"
		return $RET
	fi
	diff -u $OUTPUT_DIR/ethtool.raw ${MACHINE_MODEL_}.ethtool
	echo "DEBUG: diff $?"
}

echo "DEBUG: list interface"
ls /sys/class/net/
for iface in $(ls /sys/class/net/)
do
	echo "DEBUG: Found interface $iface"
	if [ "$iface" == 'lo' ];then
		echo "SKIP: dont check $iface"
		continue
	fi
	test_interface $iface
done

start_test "Detect ethtool"
/usr/sbin/ethtool --version
if [ $? -eq 0 ];then
	HAVE_ETHTOOL=1
fi
result 0 "detect-ethtool"

if [ $HAVE_ETHTOOL -eq 1 ];then
	start_test "Run ethtool"
	/usr/sbin/ethtool eth0
	result $? test-ethtool

	compare_ethtool
fi

start_test "Detect mii-tool"
/sbin/mii-tool eth0
result SKIP "mii-tool"

start_test "Detect an iperf server"
ping -c4 iperf.lava.local
is_network_v4_ok
if [ $? -eq 0 ];then
	/usr/bin/iperf3 -c iperf.lava.local
	result SKIP "iperf"
else
	result SKIP "iperf"
fi

dmesg | grep -vf dmesg.ignore | grep -iE 'warn|error|fail'
result SKIP "dmesg"

# re dmesg

# check counter ifconfig

if [ $HAVE_ETHTOOL -eq 1 -a $NBD_ROOT -eq 0 ];then
	netdev=$INTERFACE
	# keep supported speed mode
	CURRENT_SPEED=$(ethtool $INTERFACE |grep Speed: | grep -o '[0-9]*')
	CURRENT_DUPLEX=$(ethtool $INTERFACE |grep Duplex: | grep -o '[A-Za-z]*$')
	if [ "$CURRENT_DUPLEX" = 'Full' ];then
		CURRENT_DUPLEX='full'
	fi
	if [ "$CURRENT_DUPLEX" = 'Half' ];then
		CURRENT_DUPLEX='half'
	fi
	echo "DEBUG: Detected $CURRENT_SPEED $CURRENT_DUPLEX"

	ethtool $INTERFACE | sed 's,Half[[:space:]]*,half\n,g' | sed 's,Full[[:space:]]*,full\n,g' | sed 's,10[0-9]*base,\n&,' |grep -v '^[[:space:]]*$' > $OUTPUT_DIR/ethtool.${INTERFACE}.out
	READMODE=""
	while read line
	do
		echo $line | grep -q 'Supported link modes'
		if [ $? -eq 0 ] ;then
			echo "DEBUG: begin supported"
			READMODE='SUPPORTED'
			continue
		fi
		echo $line | grep -q 'Link partner advertised link modes'
		if [ $? -eq 0 ] ;then
			echo "DEBUG: begin parnter"
			READMODE='PARTNER'
			continue
		fi
		echo "$line" |grep -q '^[0-9]'
		if [ $? -ne 0 ] ;then
			READMODE=''
			continue
		fi
		case $READMODE in
		'SUPPORTED')
			echo "DEBUG: Found supported $line"
			echo "$line" >> $OUTPUT_DIR/ethtool.mode.supported
		;;
		'PARTNER')
			echo "DEBUG: Found partner $line"
			echo "$line" >> $OUTPUT_DIR/ethtool.mode.partner
		;;
		*)
			echo "DEBUG: Ignore $line"
		;;
		esac
	done < $OUTPUT_DIR/ethtool.${INTERFACE}.out

	while read ethmode
	do
		DUPLEX=$(echo $ethmode | cut -d'/' -f2)
		SPEED=$(echo $ethmode | grep -o '^[0-9][0-9]*')
		# check that partner support it
		if [ -s $OUTPUT_DIR/ethtool.mode.partner ];then
			grep -q $ethmode $OUTPUT_DIR/ethtool.mode.partner
			if [ $? -ne 0 ];then
				result SKIP "network-$netdev-link-$ethmode"
				continue
			fi

		fi
		echo "DEBUG: TEST $SPEED $DUPLEX"
		kci_netdev_ethtool_test 666 "change-speed-to-$ethmode" "ethtool -s $netdev speed $SPEED duplex $DUPLEX" "$netdev"
		# give network some time to detect a link
		sleep 2
		#check if link is up
		ip link show $netdev |grep -q NO-CARRIER
		if [ $? -eq 0 ];then
			result 1 "network-$netdev-link-$ethmode"
		else
			result 0 "network-$netdev-link-$ethmode"
		fi
	done < $OUTPUT_DIR/ethtool.mode.supported
	#go back to current mode
	kci_netdev_ethtool_test 666 "change-speed-to-$ethmode" "ethtool -s $netdev speed $CURRENT_SPEED duplex $CURRENT_DUPLEX" "$netdev"

fi

