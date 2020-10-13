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
	exit 0
else
	echo "DEBUG: detected $GATEWAY_IP as gateway"
fi
ping -c 4 "$GATEWAY_IP"
result $? "ping-gateway"

grep nameserver /proc/net/pnp | cut -d' ' -f2 > "$OUTPUT_DIR/nameservers"
while read -r nameserver
do
	start_test "Test nameserver $nameserver"
	ping -c 4 "$nameserver"
	result $? "ping-nameserver-$nameserver"
done < "$OUTPUT_DIR/nameservers"

start_test "Test external network"
ping -c 4 8.8.8.8
result $? "external-network"

start_test "Test DNS"
ping -c 4 dns.google.com
result $? "dns"
