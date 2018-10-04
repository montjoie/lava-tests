#!/bin/sh

. ./common

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

for iface in $(ls /sys/class/net/)
do
	echo "DEBUG: Found $iface"
	if [ "$iface" == 'lo' ];then
		continue
	fi
	test_interface $1
done

/usr/sbin/ethtool --version
if [ $? -eq 0 ];then
	HAVE_ETHTOOL=1
fi

/usr/sbin/ethtool eth0
result $? test-ethtool

start_test "Detect mii-tool"
/sbin/mii-tool eth0
result SKIP "mii-tool"

start_test "Detect an iperf server"
ping -c4 iperf.lava.local
is_network_v4_ok
if [ $? -eq 0 ];then
	#/usr/bin/iperf3 -c 192.168.1.100
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
	ethtool $INTERFACE |grep -o [0-9][0-9]*baseT/[A-Za-z]* | sort | uniq |
	while read ethmode
	do
		DUPLEX=$(echo $ethmode | cut -d'/' -f2)
		SPEED=$(echo $ethmode | grep -o '^[0-9][0-9]*')
		if [ "$DUPLEX" = 'Full' ];then
			DUPLEX='full'
		fi
		if [ "$DUPLEX" = 'Half' ];then
			DUPLEX='half'
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
	done
	#go back to maximum
	kci_netdev_ethtool_test 666 "change-speed-to-$ethmode" "ethtool -s $netdev speed $CURRENT_SPEED duplex $CURRENT_DUPLEX" "$netdev"

fi

