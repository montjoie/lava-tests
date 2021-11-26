#!/bin/sh

grep -q ' nfs ' /proc/mounts
RET=$?
if [ $RET -eq 0 ];then
	echo "DEBUG: nfs detected, skipping ipsec test"
	exit 0
fi

SRC=192.168.1.0/24
DST=iperf.lava.local

. ./common

check_config INET_AH
check_config INET_ESP
check_config INET_XFRM_TUNNEL
check_config XFRM_USER
check_config XFRM_INTERFACE
check_config CRYPTO_AES
check_config CRYPTO_SHA1

start_test "Check support of IPSEC"
# https://vincent.bernat.im/fr/blog/2017-vpn-ipsec-route
# https://gist.github.com/vishvananda/7094676
ip xfrm state
RET=$?
if [ $RET -ne 0 ];then
	result SKIP "ipsec"
	exit 0
fi
result 0 "ipsec-xfrm-state"

ping -c4 ipsec.lava.local
RET=$?
#if [ $RET -ne 0 ];then
	#result SKIP "ipsec"
	#exit 0
#fi

start_test "get strongswan version"
ipsec version
result $? "ipsec-version"

date

wget -q http://ipsec.lava.local/cacert.crt
wget -q http://ipsec.lava.local/lava.crt
wget -q http://ipsec.lava.local/dut.crt
wget -q http://ipsec.lava.local/dut.key
wget -q http://ipsec.lava.local/ipsec.conf

start_test "IPSEC: download ipsec.secrets"
wget -q http://ipsec.lava.local/ipsec.secrets
result $? "ipsec-download-secrets"

mv dut.key /etc/ipsec.d/private/
mv dut.crt /etc/ipsec.d/certs/
mv lava.crt /etc/ipsec.d/certs/
mv cacert.crt /etc/ipsec.d/cacerts/
mv ipsec.conf /etc/
mv ipsec.secrets /etc/

start_test "IPSEC: start"
ipsec start
result $? "ipsec-start"

sleep 8

ps aux |grep -E 'ipsec|swan|charon'

start_test "IPSEC: listalgs"
ipsec listalgs
result $? "ipsec-listalgs"

start_test "IPSEC: statusall"
ipsec statusall
result $? "ipsec-statusall"

start_test "IPSEC: listcerts"
ipsec listcerts
result $? "ipsec-listcerts"

start_test "IPSEC: dump policy"
ip xfrm policy
result $? "ipsec-policy-dump"

start_test "IPSEC: dump state"
ip xfrm state
result $? "ipsec-state-dump1"

start_test "Get crypto stat"
getstat > getstat.orig
result $? "ipsec-getstat-orig"

print_crypto_stat

start_test "IPSEC: ping via ipsec"
ping -c4 ipsec.lava.local
result $? "ipsec-ping"

start_test "IPSEC: iperf TCP"
iperf3 --port 5201 -c ipsec.lava.local
result $? "ipsec-iperf-tcp"

start_test "IPSEC: iperf udp"
iperf3 --udp --port 5201 -c ipsec.lava.local
result $? "ipsec-iperf-udp"

start_test "IPSEC: getstat new"
getstat > getstat.new
result $? "ipsec-getstat-new"
diff -u getstat.orig getstat.new

print_crypto_stat

start_test "IPSEC: dump state at the end"
ip xfrm state
result $? "ipsec-state-dump2"

start_test "IPSEC: statusall at the end"
ipsec statusall > $OUTPUT_DIR/ipsec-statusall
RET=$?
cat $OUTPUT_DIR/ipsec-statusall
result $RET "ipsec-statusall-end"
# check number of packets
PKTS_I=$(grep 'lava{' $OUTPUT_DIR/ipsec-statusall | grep -o 'bytes_i ([0-9]* pkts' | cut -d'(' -f2 | cut -d' ' -f1)
PKTS_O=$(grep 'lava{' $OUTPUT_DIR/ipsec-statusall | grep -o 'bytes_o ([0-9]* pkts' | cut -d'(' -f2 | cut -d' ' -f1)
echo "DEBUG: got PKTS_I=$PKTS_I PKTS_O=$PKTS_O"

start_test "IPSEC: check input packets"
if [ -z "$PKTS_I" ];then
	result FAIL "ipsec-packets-input"
else
	if [ "$PKTS_I" -eq 0 ];then
		result FAIL "ipsec-packets-input"
	else
		result 0 "ipsec-packets-input"
	fi
fi

start_test "IPSEC: check output packets"
if [ -z "$PKTS_O" ];then
	result FAIL "ipsec-packets-output"
else
	if [ "$PKTS_O" -eq 0 ];then
		result FAIL "ipsec-packets-output"
	else
		result 0 "ipsec-packets-output"
	fi
fi

ls /var/log
cat /var/log/messages

exit 0
