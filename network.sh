#!/bin/sh

. ./common

get_machine_model

HAVE_ETHTOOL=0
TEST_PREFIX="test-network"
NBD_ROOT=0
NFS_ROOT=0

start_test "Detect the use of a NBD root"
grep -i "nbd" /proc/mounts
RET=$?
if [ $RET -eq 0 ];then
	NBD_ROOT=1
	# TODO detect on which interface NBD/NFS link is done
fi
result 0 "network-nbd-root"

start_test "Detect the use of a NFS root"
grep -i "nfs" /proc/mounts
RET=$?
if [ $RET -eq 0 ];then
	NFS_ROOT=1
	# TODO detect on which interface NBD/NFS link is done
fi
result 0 "network-nfs-root"

start_test "Detect ip"
check_tool "ip"
result 0 "network-detect-ip"

start_test "Detect ethtool"
check_tool "ethtool"
RET=$?
if [ $RET -eq 0 ];then
	HAVE_ETHTOOL=1
fi
result 0 "network-detect-ethtool"

start_test "Run ip"
ip a
result $? "network-ip-a"

start_test "Run ifconfig"
ifconfig
result $? "network-ifconfig"

start_test "Run ip route"
ip route
result $? "network-ip-route"

start_test "Test gateway"
GATEWAY_IP=$(ip route |grep ^default | cut -d' ' -f3)
ping -c4 "$GATEWAY_IP"
result $? "network-ping-gateway"

grep nameserver /proc/net/pnp | cut -d' ' -f2 > "$OUTPUT_DIR/nameservers"
while read -r nameserver
do
	start_test "Test nameserver $nameserver"
	ping -c 4 "$nameserver"
	result $? "ping-nameserver-$nameserver"
done < "$OUTPUT_DIR/nameservers"

start_test "Test external network"
ping -c4 8.8.8.8
result $? "external-network"

start_test "Test DNS"
ping -c4 dns.google.com
result $? "dns"

# test an ethtool command
# arg1: return code for not supported (see ethtool code source)
# arg2: summary of the command
# arg3: command to execute
# arg4: netdev used
kci_netdev_ethtool_test()
{
	summary=$2
	netdev=$4
	if [ $# -ne 4 ];then
		echo "FAIL: ethtool: invalid number of arguments"
		return 1
	fi
	start_test "Test ethtool $summary on $netdev"
	echo "DEBUG: run $3"
	$3
	ret=$?
	if [ $ret -ne 0 ];then
		if [ $ret -eq "$1" ];then
			result SKIP --sleep 3 "network-$netdev-ethtool-$summary"
			return 0
		else
			echo "DEBUG: return code=$ret"
			result $ret --sleep 3 "network-$netdev-ethtool-$summary"
			return 0
		fi
	else
		result 0 --sleep 3 "network-$netdev-ethtool-$summary"
	fi
	return 0
}


test_interface() {
	if [ -z "$1" ];then
		echo "ERROR: Missing argument to test_interface()"
		return 1
	fi
	netdev="$1"
	echo "DEBUG: test_interface $netdev"

	if [ $HAVE_ETHTOOL -ne 1 ];then
		return 0
	fi

	start_test "Run ethtool for $netdev"
	ethtool "$netdev"
	result $? "network-$netdev-ethtool-basic"

	start_test "Get features list from $netdev"
	ethtool -k "$netdev"
	result $? "network-$netdev-ethtool-features-list"

	kci_netdev_ethtool_test 74 'selftest' "ethtool --test $netdev online" "$netdev"
	kci_netdev_ethtool_test 74 'dump' "ethtool -d $netdev" "$netdev"
	kci_netdev_ethtool_test 94 'stats' "ethtool -S $netdev" "$netdev"

	# disruptive test begins here
	if [ $NBD_ROOT -eq 1 ];then
		echo "DEBUG: bypassing test on $netdev due to NBD"
		return 0
	fi
	if [ $NFS_ROOT -eq 1 ];then
		echo "DEBUG: bypassing test on $netdev due to NFS"
		return 0
	fi
	echo "DEBUG: disruptive test begin on $netdev"
	#TODO detect if interface got an IP
	NETDEV_HAS_IP=1
	# test mtu change
	#ifconfig eth0 mtu 1400
	ip link show $netdev > $OUTPUT_DIR/iplink
	OMTU=$(grep -o 'mtu [0-9]*' $OUTPUT_DIR/iplink | cut -d' ' -f2)
	echo "DEBUG: original MTU is $OMTU"

	for mtu in 68 500 1000 1200 1400 1500 1600 9000
	do
		if [ $mtu -eq $OMTU ];then
			echo "DEBUG: skip $mtu as same as old MTU"
			continue
		fi
		start_test "down $netdev for changing MTU"
		ip link set $netdev down
		result $? "network-$netdev-mtu-$mtu-down"

		start_test "Set MTU to $mtu"
		ip link set $netdev mtu $mtu
		result $? "network-$netdev-mtu-$mtu"

		start_test "up $netdev for changing MTU"
		ip link set $netdev up
		result $? "network-$netdev-mtu-$mtu-up"

		echo "======================== MTU $mtu"
		sleep 4
		if [ $NETDEV_HAS_IP -eq 1 ];then
			ip link show $netdev
			udhcpc -i $netdev -q -f -n
			sleep 5
			ip a |grep -q 192.168
			if [ $? -ne 0 ];then
				ip a add 192.168.1.204 dev $netdev
				ip route add default gw 192.168.1.1
			fi
			ip a
		fi
		echo "========================"
		start_test "test ping with MTU $mtu"
		ping -c 2 8.8.8.8
		result $? "network-$netdev-mtu-$mtu-ping"
	done

	start_test "down $netdev for changing MTU to $OMTU"
	ip link set $netdev down
	result $? "network-$netdev-mtu-$OMTU-down"
	start_test "Restore MTU to $OMTU"
	ip link set $netdev mtu $OMTU
	result $? "network-$netdev-mtu-restore-$OMTU"
	start_test "up $netdev for changing MTU"
	ip link set $netdev up
	result $? "network-$netdev-mtu-$OMTU-up"

	echo "========================"
	if [ $NETDEV_HAS_IP -eq 1 ];then
		udhcpc -i $netdev -q -f -n
		sleep 5
		ip a |grep -q 192.168
		if [ $? -ne 0 ];then
			ip a add 192.168.1.204 dev $netdev
			ip route add default gw 192.168.1.1
		fi
		ip a
	fi
	ip link show $netdev
	echo "========================"

	# keep supported speed mode
	CURRENT_SPEED=$(ethtool "$netdev" |grep 'Speed:' | grep -o '[0-9]*')
	CURRENT_DUPLEX=$(ethtool "$netdev" |grep 'Duplex:' | grep -o '[A-Za-z]*$')
	if [ "$CURRENT_DUPLEX" = 'Full' ];then
		CURRENT_DUPLEX='full'
	fi
	if [ "$CURRENT_DUPLEX" = 'Half' ];then
		CURRENT_DUPLEX='half'
	fi
	if [ -z "$CURRENT_DUPLEX" ];then
		echo "DEBUG: no duplex"
		return 0
	fi
	echo "DEBUG: Detected $CURRENT_SPEED $CURRENT_DUPLEX on $netdev"

	ethtool "$netdev" | sed 's,Half[[:space:]]*,half\n,g' | sed 's,Full[[:space:]]*,full\n,g' | sed 's,10[0-9]*base,\n&,' |grep -v '^[[:space:]]*$' > "$OUTPUT_DIR/ethtool.${netdev}.out"
	READMODE=""
	while read -r line
	do
		echo "$line" | grep -q 'Supported link modes'
		RET=$?
		if [ $RET -eq 0 ] ;then
			echo "DEBUG: begin supported"
			READMODE='SUPPORTED'
			continue
		fi
		echo "$line" | grep -q 'Link partner advertised link modes'
		RET=$?
		if [ $RET -eq 0 ] ;then
			echo "DEBUG: begin partner"
			READMODE='PARTNER'
			continue
		fi
		echo "$line" |grep -q '^[0-9]'
		RET=$?
		if [ $RET -ne 0 ] ;then
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
			echo "$line" >> "$OUTPUT_DIR/ethtool.mode.partner"
		;;
		*)
			echo "DEBUG: Ignore $line"
		;;
		esac
	done < "$OUTPUT_DIR/ethtool.${netdev}.out"

	# test all modes
	while read -r ethmode
	do
		DUPLEX=$(echo "$ethmode" | cut -d'/' -f2)
		SPEED=$(echo "$ethmode" | grep -o '^[0-9][0-9]*')
		# check that partner support it
		if [ -s "$OUTPUT_DIR/ethtool.mode.partner" ];then
			grep -q "$ethmode" "$OUTPUT_DIR/ethtool.mode.partner"
			RET=$?
			if [ $RET -ne 0 ];then
				result SKIP "network-$netdev-link-$ethmode"
				continue
			fi

		fi
		echo "DEBUG: TEST $SPEED $DUPLEX"
		kci_netdev_ethtool_test 666 "change-speed-to-$ethmode" "ethtool -s $netdev speed $SPEED duplex $DUPLEX" "$netdev"
		# give network some time to detect a link
		sleep 3
		#check if link is up
		ip link show "$netdev" |grep -q 'NO-CARRIER'
		RET=$?
		if [ $RET -eq 0 ];then
			result 1 "network-$netdev-link-$ethmode"
		else
			result 0 "network-$netdev-link-$ethmode"
		fi
	done < "$OUTPUT_DIR/ethtool.mode.supported"

	#go back to current mode
	kci_netdev_ethtool_test 666 "change-speed-back" "ethtool -s $netdev speed $CURRENT_SPEED duplex $CURRENT_DUPLEX" "$netdev"
	return 0
}

# compare current ethtool output with a reference one
# TODO enhance those test
compare_ethtool() {
	/usr/sbin/ethtool eth0 > "$OUTPUT_DIR/ethtool.raw"
	RET=$?
	if [ $RET -ne 0 ];then
		echo "DEBUG: Should not fail"
		return $RET
	fi
	wget "http://kernel.montjoie.ovh/reference/${MACHINE_MODEL_}.ethtool"
	RET=$?
	if [ $RET -ne 0 ];then
		echo "DEBUG: Cannot get reference ethtool for ${MACHINE_MODEL_}"
		return $RET
	fi
	diff -u "$OUTPUT_DIR/ethtool.raw" "${MACHINE_MODEL_}.ethtool"
	echo "DEBUG: diff $?"
}

#for iface in $(ls /sys/class/net/)
for f in /sys/class/net/*
do
	iface=$(basename "$f")
	driverpath=$(readlink "$f/device/driver")
	driver=$(basename "$driverpath")
	if [ -z "$driver" ]; then
		echo "SKIP: dont check $iface with no driver"
	fi
	if [ -e "$f/phydev/driver" ];then
		phydevpath=$(readlink "$f/phydev/driver")
		phydev=$(basename "$phydevpath")
		echo "DEBUG: Using phydev $phydev"
	fi
	echo "DEBUG: Found interface $iface with driver=$driver"
	if [ "$iface" = 'lo' ];then
		echo "SKIP: dont check $iface"
		continue
	fi
	test_interface "$iface"
done

# TODO add mii-tool to rootfs
#start_test "Detect mii-tool"
#/sbin/mii-tool eth0
#result SKIP "mii-tool"

iperf3 -c iperf.lava.local -V
do_iperf auto network

# TODO check counter ifconfig
