#!/bin/sh

. ./common

check_config WATCHDOG

start_test "Verify presence of watchdog binary"
watchdog --version
result $? "watchdog-binary"

cat /etc/watchdog.conf

#find /sys |grep watchdog

watchdog_test_ping() {
	ip route
	GATEWAY_IP=$(ip route |grep ^default | cut -d' ' -f3)
	if [ -z "$GATEWAY_IP" ];then
		return 0
	fi
	echo "DEBUG: adding $GATEWAY_IP"
	echo "ping=$GATEWAY_IP" >> /etc/watchdog.conf

	echo "test-timeout=5" >> /etc/watchdog.conf

	echo "watchdog-device=/dev/watchdog" >> /etc/watchdog.conf

	watchdog --config-file /etc/watchdog.conf -v --no-action
	echo "RET $?"
	ps aux |grep watch

	sleep 10

	start_test "firewall default gateway"
	iptables -I OUTPUT -d $GATEWAY_IP -j DROP
	result $? "watchdog-firewall"

	iptables -L -v -n

	sleep 20
	dmesg | tail -n 40
	iptables -L -v -n
	ls -l /var/log/
	tail -n40 /var/log/messages
	ls -l /var/log/watchdog
}

watchdog_test_ping
