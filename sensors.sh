#!/bin/sh

. ./common

check_config HWMON
check_config THERMAL_HWMON

echo "DEBUG: thermal"
find /sys -iname "temp*" |grep thermal |
while read line
do
	echo "DEBUG: Found $line"
	THERMAL_BASE=$(dirname $line)
	if [ -e "$THERMAL_BASE/name" ];then
		THERMAL_NAME="$(cat $THERMAL_BASE/name)"
	else
		if [ -e $THERMAL_BASE/type ];then
			THERMAL_NAME="$(cat $THERMAL_BASE/type)"
		else
			THERMAL_NAME="unset-notype"
			ls -l $THERMAL_BASE
		fi
	fi
	start_test "Read $THERMAL_NAME"
	cat $line
	result $? "sensor-thermal-$THERMAL_NAME"
done
echo "DEBUG: end thermal"

start_test "Run sensors-detect"
sensors-detect --auto
result $? "sensors-detect"

ls /sys/class/hwmon/ > /sensor.list
if [ ! -s /sensor.list ];then
	result SKIP "sensor"
	exit 0
fi

start_test "Run sensor"
sensors
result $? "sensor"

for sensor in $(ls /sys/class/hwmon/)
do
	NAME=$(cat /sys/class/hwmon/$sensor/name)
	start_test "Check sensor $NAME"
	ls /sys/class/hwmon/$sensor/*_input 2>/dev/null >/dev/null
	if [ $? -ne 0 ];then
		result skip "sensor-$NAME"
		continue
	fi
	RET=0
	for capt in $(ls /sys/class/hwmon/$sensor/*_input | sed 's,^.*/,,' | sed 's,_input,,')
	do
		echo "DEBUG: found capteur $capt"
		V="$(cat /sys/class/hwmon/$sensor/${capt}_input)"
		lava-test-case "sensor-$NAME-$capt" --result pass --measurement $V --units milidegC
	done
	result $RET "sensor-$NAME"
done
