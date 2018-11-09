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
		lava-test-case "boot-log-${loglevel}" --result PASS
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
		lava-test-case "boot-log-${loglevel}" --result PASS
	fi
done
