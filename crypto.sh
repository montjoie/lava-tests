#!/bin/sh

. ./common

test_rng()
{
	TEST_RNG_SKIP=0
	check_config CRYPTO_USER_API_RNG=
	if [ $? -ne 0 ];then
		TEST_RNG_SKIP=1
	fi

while read line
do
	TYPE=$(echo $line |cut -d' ' -f1)
	case $TYPE in
	driver)
		DRIVER=$(echo $line | sed 's,.*[[:space:]],,')
	;;
	type)
		TYPE=$(echo $line | sed 's,.*[[:space:]],,')
		if [ "$TYPE" = 'rng' ];then
			start_test "Test $DRIVER with kcapi-rng"
			if [ $TEST_RNG_SKIP -eq 0 ];then
				scripts/testrng.sh $DRIVER $OUTPUT_DIR &
				PID=$!
				timeelapsed=0
				while [ $timeelapsed -le 120 ]
				do
					if [ -e $OUTPUT_DIR/rng.ret ];then
						break
					fi
					sleep 1
					timeelapsed=$(($timeelapsed+1))
				done
				if [ $timeelapsed -ge 120 ];then
					kill $PID
					echo "ERROR: RNG timeout!"
					RET=1
				else
					RET=$(cat $OUTPUT_DIR/rng.ret)
					echo "DEBUG: rng exit ret=$RET after $timeelapsed seconds"
				fi
				rm -f $OUTPUT_DIR/rng.ret
				rm -f $OUTPUT_DIR/rng.out
				result $RET "crypto-RNG-$DRIVER"
			else
				result SKIP "crypto-RNG-$DRIVER"
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
try_run "modprobe tcrypt" 2> $OUTPUT_DIR/tcrypt.err
RET=$?
cat $OUTPUT_DIR/tcrypt.err
if [ $RET -eq 0 ];then
	# never happen
	echo "WARN: should not happen"
	result 0 "crypto-tcrypt"
else
	if [ $RET -eq 1 ];then
		# normal case, check error message
		grep -q 'Resource temporarily unavailable' $OUTPUT_DIR/tcrypt.err
		if [ $? -eq 0 ];then
			echo "DEBUG: tcrypt real success"
			result 0 "crypto-tcrypt"
		else
			result 0 "crypto-tcrypt"
		fi
	else
		echo "DEBUG: unknow return code $RET"
		result $RET "crypto-tcrypt"
	fi
fi

kcapi-rng --version
if [ $? -eq 0 ];then
	test_rng
else
	result SKIP "crypto-RNG"
fi

# HWRNG tests

if [ -e /sys/devices/virtual/misc/hw_random/ ];then
	echo "==================== Found hwrng ==============="
	cat /sys/devices/virtual/misc/hw_random/rng_available
	cat /sys/devices/virtual/misc/hw_random/rng_current
	HWRNG_NAME="$(cat /sys/devices/virtual/misc/hw_random/rng_current | sed 's, ,_,g')"
	cat /sys/devices/virtual/misc/hw_random/rng_selected
	echo "================================================"
fi

if [ -e /dev/hwrng -a "$HWRNG_NAME" != 'none' ];then
	start_test "Check hwrng $HWRNG_NAME"
	dd if=/dev/hwrng count=1 bs=512 > /dev/null
	result $? "hwrng-simple-$HWRNG_NAME"
	rngtest -V
	if [ $? -eq 0 ];then
		start_test "Check hwrng with rngtest"
		dd if=/dev/hwrng count=100 bs=1024 | rngtest
		result $? "hwrng-rngtest1-$HWRNG_NAME"
		start_test "Check hwrng with rngtest"
		dd if=/dev/hwrng count=100 bs=2048 | rngtest
		result $? "hwrng-rngtest2-$HWRNG_NAME"
	fi
fi

# check for some result
# tcrypt generate error -2 for non-present algs
start_test "Verify crypto errors"
dmesg | grep -vE 'is unavailable$|[[:space:]]-2$|This is intended for developer use only|alg: No test for stdrng' |grep alg:
if [ $? -eq 0 ];then
	result 1 "crypto-error-log"
else
	result 0 "crypto-error-log"
fi

print_crypto_stat

echo "=== DUMP /proc/crypto ==="
cat /proc/crypto
echo "=== END DUMP ==="

while read line
do
	SECTION=$(echo $line |cut -d' ' -f1)
	case $SECTION in
	driver)
		DRIVER=$(echo $line | sed 's,.*[[:space:]],,' | sed 's,[()],_',g)
	;;
	type)
		TYPE=$(echo $line | sed 's,.*[[:space:]],,')
	;;
	selftest)
		SELFTEST=$(echo $line | sed 's,.*[[:space:]],,')
	;;
	"")
		if [ "$SELFTEST" == 'passed' ];then
			RESULT='pass'
		else
			RESULT='fail'
		fi
		lava-test-case $TYPE-$DRIVER --result $RESULT
	;;
	*)
	;;
	esac
done < /proc/crypto
