#!/bin/sh

grep -q ' nfs ' /proc/mounts
RET=$?
if [ $RET -eq 0 ];then
	echo "DEBUG: nfs detected, skipping ipsec test"
	exit 0
fi

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
if [ $RET -eq 0 ];then
	echo "ERROR: ping should not work without ipsec"
fi

start_test "get strongswan version"
ipsec version
result $? "ipsec-version"

date

start_test "IPSEC: download cacert"
wget -q http://ipsec.lava.local/cacert.crt
RET=$?
result $RET "ipsec-download-cacert"
if [ $RET -ne 0 ];then
	echo "ABORTING TESTS"
	exit 0
fi

start_test "IPSEC: download lava.crt"
wget -q http://ipsec.lava.local/lava.crt
RET=$?
result $RET "ipsec-download-lava"
if [ $RET -ne 0 ];then
	exit 0
fi

wget -q http://ipsec.lava.local/dut.crt
wget -q http://ipsec.lava.local/dut.key
wget -q http://ipsec.lava.local/ipsec.conf

start_test "IPSEC: download ipsec.secrets"
wget -q http://ipsec.lava.local/ipsec.secrets
result $? "ipsec-download-secrets"

mv dut.key /etc/ipsec.d/private/ || exit $?
mv dut.crt /etc/ipsec.d/certs/ || exit $?
mv lava.crt /etc/ipsec.d/certs/ || exit $?
mv cacert.crt /etc/ipsec.d/cacerts/ || exit $?
mv ipsec.conf /etc/ || exit $?
mv ipsec.secrets /etc/ || exit $?

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

print_crypto_stat

start_test "IPSEC: ping via ipsec"
ping -c4 ipsec.lava.local
result $? "ipsec-ping"

# the ping has force the tunnel to be setuped, we can check which algo is used now
start_test "IPSEC: find selected algorithm"
ipsec statusall > $OUTPUT_DIR/ipsec-statusall
IPSEC_ALGO=$(grep 'IKE proposal' $OUTPUT_DIR/ipsec-statusall |grep -o 'AES_[A-Z0-9_/]*' | sed 's,/,_,g')
echo "DEBUG: IPSEC ALGO is $IPSEC_ALGO"
RET=0
if [ -z "$IPSEC_ALGO" ];then
	RET=1
fi
result $RET "ipsec-find-algo"

start_test "IPSEC: iperf TCP"
iperf3 --port 5201 -c ipsec.lava.local -V
result $? "ipsec-iperf-tcp"
do_iperf ipsec.lava.local ipsec-tcp-{IPSEC_ALGO} --report http://192.168.1.40:8089/bin/bwreport.py --port 5201

start_test "IPSEC: iperf udp"
iperf3 --udp --port 5201 -c ipsec.lava.local -V
result $? "ipsec-iperf-udp"
do_iperf ipsec.lava.local ipsec-udp --udp --port 5201

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
