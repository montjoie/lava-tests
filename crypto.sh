#!/bin/sh

. ./common

test_rng()
{
	TEST_RNG_SKIP=0
	check_config 'CRYPTO_USER_API_RNG='
	RET=$?
	if [ $RET -ne 0 ];then
		TEST_RNG_SKIP=1
	fi

while read -r line
do
	TYPE=$(echo "$line" |cut -d' ' -f1)
	case "$TYPE" in
	driver)
		DRIVER=$(echo "$line" | sed 's,.*[[:space:]],,')
	;;
	type)
		TYPE=$(echo "$line" | sed 's,.*[[:space:]],,')
		if [ "$TYPE" = 'rng' ];then
			start_test "Test $DRIVER with kcapi-rng"
			if [ $TEST_RNG_SKIP -eq 0 ];then
				scripts/testrng.sh "$DRIVER" "$OUTPUT_DIR" &
				PID=$!
				timeelapsed=0
				while [ "$timeelapsed" -le 120 ]
				do
					if [ -e "$OUTPUT_DIR/rng.ret" ];then
						break
					fi
					sleep 1
					timeelapsed=$((timeelapsed+1))
				done
				if [ "$timeelapsed" -ge 120 ];then
					kill $PID
					echo "ERROR: RNG timeout!"
					RET=1
				else
					RET=$(cat "$OUTPUT_DIR/rng.ret")
					echo "DEBUG: rng exit ret=$RET after $timeelapsed seconds"
				fi
				rm -f "$OUTPUT_DIR/rng.ret"
				rm -f "$OUTPUT_DIR/rng.out"
				result "$RET" "crypto-RNG-$DRIVER"
			else
				result "SKIP" "crypto-RNG-$DRIVER"
			fi
		fi
	;;
	*)
	;;
	esac
done < /proc/crypto
}

print_crypto_stat

# for all crypto algorithm to load by testing them via the tcrypt module
start_test "Test kernel crypto via the tcrypt module"
#modprobe tcrypt 2> $OUTPUT_DIR/tcrypt.err
try_run -t 180 "modprobe tcrypt" 2> "$OUTPUT_DIR/tcrypt.err"
RET=$?
cat "$OUTPUT_DIR/tcrypt.err"
if [ $RET -eq 0 ];then
	# should never happen in classic testing (non-FIPS)
	# TODO test for FIPS mode
	echo "WARN: should not happen"
	result 0 "crypto-tcrypt"
else
	if [ $RET -eq 1 ];then
		# normal case, check error message
		# by default tcrypt return EAGAIN in non-FIPS mode
		grep -q 'Resource temporarily unavailable' "$OUTPUT_DIR/tcrypt.err"
		RET=$?
		if [ $RET -eq 0 ];then
			echo "DEBUG: tcrypt real success"
			result 0 "crypto-tcrypt"
		else
			grep -q 'module tcrypt not found' "$OUTPUT_DIR/tcrypt.err"
			RET=$?
			if [ $RET -eq 0 ];then
				result SKIP "crypto-tcrypt"
			else
				result 0 "crypto-tcrypt"
			fi
		fi
	else
		echo "DEBUG: unknow return code $RET"
		result $RET "crypto-tcrypt"
	fi
fi

print_crypto_stat

kcapi-rng --version
RET=$?
if [ $RET -eq 0 ];then
	test_rng
else
	result "SKIP" "crypto-RNG"
fi

# HWRNG tests

if [ -e /sys/devices/virtual/misc/hw_random/ ];then
	echo "==================== Found hwrng ==============="
	cat /sys/devices/virtual/misc/hw_random/rng_available
	cat /sys/devices/virtual/misc/hw_random/rng_current
	HWRNG_NAME="$(sed 's, ,_,g' /sys/devices/virtual/misc/hw_random/rng_current)"
	cat /sys/devices/virtual/misc/hw_random/rng_selected
	echo "================================================"
fi

test_hwrng()
{
	if [ ! -e /dev/hwrng ];then
		return 1
	fi
	HWRNG_NAME="$(sed 's, ,_,g' /sys/devices/virtual/misc/hw_random/rng_current)"
	if [ "$HWRNG_NAME" = 'none' ];then
		return 1
	fi
	start_test "Check hwrng $HWRNG_NAME"
	dd if=/dev/hwrng count=1 bs=512 > /dev/null
	RET=$?
	result $RET "hwrng-simple-$HWRNG_NAME"
	rngtest -V
	RET=$?
	if [ $RET -eq 0 ];then
		start_test "Check hwrng with rngtest"
		dd if=/dev/hwrng count=100 bs=1024 | rngtest
		result $? "hwrng-rngtest1-$HWRNG_NAME"
		start_test "Check hwrng with rngtest"
		dd if=/dev/hwrng count=100 bs=2048 | rngtest
		result $? "hwrng-rngtest2-$HWRNG_NAME"
	fi
	return 0
}

# TODO test all hwrng
test_hwrng

# check for some result
# tcrypt generate error -2 for non-present algs
start_test "Verify crypto errors"
dmesg | grep -vE 'is unavailable$|[[:space:]]-2$|This is intended for developer use only|alg: No test for stdrng' |grep alg:
RET=$?
if [ $RET -eq 0 ];then
	result 1 "crypto-error-log"
else
	result 0 "crypto-error-log"
fi

print_crypto_stat

#echo "=== DUMP /proc/crypto ==="
#cat /proc/crypto
#echo "=== END DUMP ==="

# verify each algorithm if thet pass or fail selftests
while read -r line
do
	SECTION=$(echo "$line" |cut -d' ' -f1)
	case $SECTION in
	driver)
		DRIVER=$(echo "$line" | sed 's,.*[[:space:]],,' | sed 's,[()],_',g)
	;;
	type)
		TYPE=$(echo "$line" | sed 's,.*[[:space:]],,')
	;;
	selftest)
		SELFTEST=$(echo "$line" | sed 's,.*[[:space:]],,')
	;;
	"")
		if [ "$SELFTEST" = 'passed' ];then
			RESULT='pass'
		else
			RESULT='fail'
		fi
		lava-test-case "$TYPE-$DRIVER" --result $RESULT
	;;
	*)
	;;
	esac
done < /proc/crypto

echo "DEBUG: check for libkcapi test"
if [ -e /usr/libexec/libkcapi/test.sh ];then
	cp /usr/libexec/libkcapi/test.sh /usr/libexec/libkcapi/test.sh.old
	sed -i 's,^[[:space:]][[:space:]]*aead,echo "aead"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^[[:space:]][[:space:]]*multipletest_aead,echo "aead"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^pbkdftest$,echo "pbkdftest"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^pbkdftest -m$,echo "pbkdftest"#,' /usr/libexec/libkcapi/test.sh
	diff -u /usr/libexec/libkcapi/test.sh.old /usr/libexec/libkcapi/test.sh
	start_test "Run libkcapi test"
	/usr/libexec/libkcapi/test.sh
	result $? "crypto-libkcapi"
	print_crypto_stat
fi
