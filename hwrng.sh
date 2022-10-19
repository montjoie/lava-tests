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

print_crypto_stat
