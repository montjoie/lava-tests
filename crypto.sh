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
				echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
				if [ $? -eq 0 ];then
					result 0 "crypto-RNG-$DRIVER"
				else
					result 1 "crypto-RNG-$DRIVER"
				fi
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

start_test "Test kernel crypto via the tcrypt module"
dmesg --console-on
modprobe tcrypt 2> $OUTPUT_DIR/tcrypt.err
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
dmesg --console-off

kcapi-rng --version
if [ $? -eq 0 ];then
	test_rng
else
	result SKIP "crypto-RNG"
fi

# check for some result
# tcrypt generate error -2 for non-present algs
start_test "Verify crypto errors"
dmesg | grep -vE 'is unavailable$|[[:space:]]-2$|This is intended for developer use only' |grep alg:
if [ $? -eq 0 ];then
	result 1 "crypto-error-log"
else
	result 0 "crypto-error-log"
fi

#TODO create a test case for each alg passed in /proc/crypto
