#!/bin/sh

. ./common

test_rng()
{
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
			echo "TEST: $DRIVER"
			echo "SEED" | kcapi-rng --name $DRIVER -b 4096 > /tmp/rng.out
			if [ $? -eq 0 ];then
				result 0 "$DRIVER"
			else
				result 1 "$DRIVER"
			fi
		fi
	;;
	*)
	;;
	esac
done < /proc/crypto
}


modprobe tcrypt
if [ $? -eq 1 ];then
	result SKIP "tcrypt"
else
	result 0 "tcrypt"
fi

kcapi-rng --version
if [ $? -eq 0 ];then
	test_rng
else
	result SKIP RNG
fi

# re dmesg

