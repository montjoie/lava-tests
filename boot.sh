#!/bin/sh

. ./common

start_test "Get machine model"
get_machine_model
if [ -z "$MACHINE_MODEL_" ];then
	result FAIL get-machine-model
else
	echo "DEBUG: Run on $MACHINE_MODEL_"
	result 0 get-machine-model
fi

check_loglevel() {
	dmesg --level $loglevel > $OUTPUT_DIR/dmesg.${loglevel}
	if [ $? -ne 0 ];then
		echo "ERROR: dmesg for $loglevel"
		return 1
	fi
	if [ -s $OUTPUT_DIR/dmesg.${loglevel} ];then
		echo "DEBUG: Got something from ${loglevel}"
		if [ -e "logignore/common/${loglevel}" ];then
			grep -v -f logignore/common/${loglevel} $OUTPUT_DIR/dmesg.${loglevel} > $OUTPUT_DIR/dmesg.${loglevel}.filter
		else
			cat $OUTPUT_DIR/dmesg.${loglevel} > $OUTPUT_DIR/dmesg.${loglevel}.filter
		fi
		# now try per board filter
		if [ -e "logignore/$MACHINE_MODEL_/${loglevel}" ];then
			echo "DEBUG: found filter for $MACHINE_MODEL_ ${loglevel}"
			mv $OUTPUT_DIR/dmesg.${loglevel}.filter $OUTPUT_DIR/dmesg.${loglevel}.filter1
			grep -v -f logignore/$MACHINE_MODEL_/${loglevel} $OUTPUT_DIR/dmesg.${loglevel}.filter1 > $OUTPUT_DIR/dmesg.${loglevel}.filter
		fi
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
		lava-test-case "boot-log-${loglevel}" --result fail
	fi
done

for loglevel in notice info debug
do
	echo "=============================================="
	echo "DEBUG: Check loglevel $loglevel"
	echo "=============================================="
	check_loglevel $loglevel
	if [ $? -eq 1 ];then
		lava-test-case "boot-log-${loglevel}" --result fail
	else
		lava-test-case "boot-log-${loglevel}" --result pass
	fi
done

# now generate a list of probed devices
#SAVED_IFD=$IFS
#IFS=''
#echo "==DRIVER_DUMP=="
#echo "==VERSION=0=="
#echo "drivers:"
#find /sys/devices/ -name uevent|
#while read line
#do
#	grep -q ^DRIVER= "$line"
#	if [ $? -eq 0 ];then
#		DRIVERNAME=$(grep ^DRIVER= "$line" |cut -d= -f2)
#		echo "  - driver: $DRIVERNAME"
#		OFNAME=$(grep OF_NAME= "$line" |cut -d= -f2)
#		if [ ! -z "$OFNAME" ];then
#			echo "    ofname: $OFNAME"
#		fi
#		grep -q ^OF_COMPATIBLE_N= "$line"
#		if [ $? -eq 0 ];then
#			echo "    compatibles:"
#			grep ^OF_COMPATIBLE_[0-9]*= "$line" | cut -d= -f2 |
#			while read compatible
#			do
#				echo "      - $compatible"
#			done
#		fi
#	fi
#done
#echo "==DRIVER_DUMP_END=="
#IFS=$SAVED_IFD

#echo "==DRIVER_DUMP=="
#echo "==VERSION=1=="
#echo "drivers:"
#find /sys/bus/*/drivers -mindepth 1 -maxdepth 1 |
#while read driver
#do
#	ls "$driver/" | while read ff
#	do
#		if [ ! -L "$driver/$ff" ];then
#			continue
#		fi
#		readlink "$driver/$ff" |grep -q devices
#		if [ $? -eq 0 ];then
#			DRIVERNAME=$(basename "$driver")
#			echo " - driver: $DRIVERNAME"
#			break
#		fi
#	done
#done
#echo "==DRIVER_DUMP_END=="

echo "==DRIVER_DUMP=="
echo "==VERSION=2=="
echo "drivers:"
find /sys/bus/*/drivers -mindepth 1 -maxdepth 1 |
while read driver
do
	echo "  - driver: $(basename "$driver")"
	find "$driver" -type l |grep -v '/module$' > list
	if [ ! -s list ];then
		continue
	fi
	echo "    list:"
	while read ff
	do
		readlink "$ff" |grep -q devices
		if [ $? -eq 0 ];then
			echo "    - bind: $(basename "$ff")"
			grep -q "^OF_COMPATIBLE_N" "$ff/uevent"
			if [ $? -eq 0 ];then
				echo "      compatible:"
				grep "OF_COMPATIBLE_[0-9]" "$ff/uevent" | cut -d= -f2 |
				while read compatible
				do
					echo "        - $compatible"
				done
			fi
		fi
	done < list
done
echo "==DRIVER_DUMP_END=="

echo "DEBUG: avallable firmware on the rootfs"
find /lib/firmware -type f
