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
	#start_test "Check hwrng $HWRNG_NAME"
	#dd if=/dev/hwrng count=1 bs=512 2>/dev/null >/dev/null
	#RET=$?
	#result $RET "hwrng-simple-$HWRNG_NAME"
	rngtest -V 2>/dev/null >/dev/null
	RET=$?
	if [ $RET -eq 0 ];then
		#start_test "Check hwrng with rngtest"
		#dd if=/dev/hwrng count=100 bs=1024 | rngtest
		#result $? "hwrng-rngtest1-$HWRNG_NAME"
		#start_test "Check hwrng with rngtest"
		dd if=/dev/hwrng count=100 bs=2048 | rngtest
		for i in $(seq 1 10)
		do
			dd if=/dev/hwrng count=100 bs=4096 | rngtest >$OUTPUT_DIR/rng.out 2>&1
			echo "=================="
			cat $OUTPUT_DIR/rng.out
			echo "=================="
			grep 'rngtest: FIPS 140-2 successes:' $OUTPUT_DIR/rng.out | sed 's,.*[[:space:]],,' >> $OUTPUT_DIR/okay-$sample
			grep 'rngtest: FIPS 140-2 failures:' $OUTPUT_DIR/rng.out | sed 's,.*[[:space:]],,' >> $OUTPUT_DIR/fail-$sample
		done
		echo "================= okay for sample=$sample"
		cat $OUTPUT_DIR/okay-$sample
		echo "================= fail for sample=$sample"
		cat $OUTPUT_DIR/fail-$sample
		SUM=0
		while read taux
		do
			#echo "DEBUG: read $taux"
			SUM=$(($SUM+$taux))
			#echo "DEBUG: SUM=$SUM"
		done < $OUTPUT_DIR/okay-$sample
		SUCMOY=$(($SUM/10))
		echo "SUCCESS: $SUM moyenne=$(($SUM/10))"
		lava-test-case "hwrng-okay-$sample" --result pass --measurement $SUCMOY --units "none"
		SUM=0
		while read taux
		do
			SUM=$(($SUM+$taux))
		done < $OUTPUT_DIR/fail-$sample
		FAILMOY=$(($SUM/10))
		echo "FAIL: $SUM moyenne=$(($SUM/10))"
		lava-test-case "hwrng-fail-$sample" --result pass --measurement $FAILMOY --units "none"
		#result $? "hwrng-rngtest2-$HWRNG_NAME"
		TOTAL=$(($SUCMOY+$FAILMOY))
		echo "FINAL SUCCESS RATE $((100*$SUCMOY/$TOTAL)) for sample=$sample"
	else
		echo "ERROR: rngtest not present"
		return 1
	fi
	return 0
}

# TODO test all hwrng
test_hwrng

print_crypto_stat

test_rk3288_crypto_rng()
{
	echo "DEBUG: test rk3288 RNG"
	if [ ! -e /sys/kernel/debug/rk3288_crypto/sample ];then
		return
	fi

	for sample in 100 200 400 500 600 700 800 1000 1200 1500 1700 2000 4000
	do
		echo "================================================="
		echo "SAMPLE $sample"
		echo "================================================="
		start_test "CHeck hwrng with sample=$sample"
		echo $sample > /sys/kernel/debug/rk3288_crypto/sample
		cat /sys/kernel/debug/rk3288_crypto/sample
		test_hwrng
		result $? "hwrng-sample-$sample"
	done
	print_crypto_stat
}

test_rk3288_crypto_rng
