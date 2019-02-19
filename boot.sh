#!/bin/sh

. ./common

check_loglevel() {
	dmesg --level $loglevel > $OUTPUT_DIR/dmesg.${loglevel}
	if [ $? -ne 0 ];then
		echo "ERROR: dmesg for $loglevel"
		return 1
	fi
	if [ -s $OUTPUT_DIR/dmesg.${loglevel} ];then
		echo "DEBUG: Got something from ${loglevel}"
		grep -vE 'urandom_read: [0-9]* callbacks suppressed|module is from the staging directory' $OUTPUT_DIR/dmesg.${loglevel} > $OUTPUT_DIR/dmesg.${loglevel}.filter
		if [ -s $OUTPUT_DIR/dmesg.${loglevel}.filter ];then
			cat $OUTPUT_DIR/dmesg.${loglevel}.filter
			return 2
		fi
	fi
	return 0
}

for loglevel in emerg alert crit err warn
do
	echo "=============================================="
	echo "DEBUG: Check loglevel $loglevel"
	echo "=============================================="
	check_loglevel $loglevel
	if [ $? -eq 0 ];then
		lava-test-case "boot-log-${loglevel}" --result pass
	else
		lava-test-case "boot-log-${loglevel}" --result FAIL
	fi
done

for loglevel in notice info debug
do
	echo "=============================================="
	echo "DEBUG: Check loglevel $loglevel"
	echo "=============================================="
	check_loglevel $loglevel
	if [ $? -eq 1 ];then
		lava-test-case "boot-log-${loglevel}" --result FAIL
	else
		lava-test-case "boot-log-${loglevel}" --result pass
	fi
done

# now generate a list of probed devices
SAVED_IFD=$IFS
IFS=''
echo "==DRIVER_DUMP=="
echo "==VERSION=0=="
echo "drivers:"
find /sys/devices/ -name uevent|
while read line
do
	grep -q ^DRIVER= "$line"
	if [ $? -eq 0 ];then
		DRIVERNAME=$(grep ^DRIVER= "$line" |cut -d= -f2)
		echo "  - driver: $DRIVERNAME"
		OFNAME=$(grep OF_NAME= "$line" |cut -d= -f2)
		if [ ! -z "$OFNAME" ];then
			echo "    ofname: $OFNAME"
		fi
		grep -q ^OF_COMPATIBLE_N= "$line"
		if [ $? -eq 0 ];then
			echo "    compatibles:"
			grep ^OF_COMPATIBLE_[0-9]*= "$line" | cut -d= -f2 |
			while read compatible
			do
				echo "      - $compatible"
			done
		fi
	fi
done
echo "==DRIVER_DUMP_END=="
IFS=$SAVED_IFD

echo "==DRIVER_DUMP=="
echo "==VERSION=1=="
echo "drivers:"
find /sys/bus/*/drivers -mindepth 1 -maxdepth 1 |
while read driver
do
	ls "$driver/" | while read ff
	do
		if [ ! -L "$driver/$ff" ];then
			continue
		fi
		readlink "$driver/$ff" |grep -q devices
		if [ $? -eq 0 ];then
			DRIVERNAME=$(basename "$driver")
			echo " - driver: $DRIVERNAME"
			break
		fi
	done
done
echo "==DRIVER_DUMP_END=="

start_test "Get machine model"
get_machine_model
if [ -z "$MACHINE_MODEL_" ];then
	result FAIL get-machine-model
else
	echo "DEBUG: Run on $MACHINE_MODEL_"
	result 0 get-machine-model
fi
