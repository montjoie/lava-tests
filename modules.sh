#!/bin/sh

. ./common

MODULES_LIST=/tmp/modules.list
MODULES_RM=/tmp/modules.rm
FINAL_CODE=0

> $MODULES_RM

try_remove() {
	sort -k3 /proc/modules | cut -d' ' -f1 > $MODULES_LIST
	if [ -s "$MODULES_LIST" ];then
		while read module
		do
			echo "DEBUG: try $module"
			rmmod $module
			if [ $? -eq 0 ];then
				echo "$module" >> $MODULES_RM
			else
				echo "DEBUG: fail to remove $module"
			fi
		done < $MODULES_LIST
		return 1
	else
		return 0
	fi
}

for i in $(seq 1 10)
do
	try_remove
	if [ $? -eq 0 ];then
		break
	fi
done

while read module
do
	echo "DEBUG: modprobe $module"
	modprobe $module
	if [ $? -ne 0 ];then
		echo "FAIL: $module"
		FINAL_CODE=1
	else
		echo "DEBUG: modprobe $module ok"
	fi
done < $MODULES_RM

rm $MODULES_LIST
rm $MODULES_RM
exit $FINAL_CODE

