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
				echo "SEED" | kcapi-rng --name $DRIVER -b 64 > /tmp/rng.out
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
modprobe tcrypt
if [ $? -eq 1 ];then
	result SKIP "crypto-tcrypt"
else
	result 0 "crypto-tcrypt"
fi

kcapi-rng --version
if [ $? -eq 0 ];then
	test_rng
else
	result SKIP "crypto-RNG"
fi

# re dmesg

