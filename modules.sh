#!/bin/sh

. ./common

MODULES_LIST=/tmp/modules.list
MODULES_RM=/tmp/modules.rm
FINAL_CODE=0

> $MODULES_RM

try_remove() {
	sort -k3 /proc/modules | grep -vf modules.remove.blacklist | cut -d' ' -f1 > $MODULES_LIST
	if [ -s "$MODULES_LIST" ];then
		while read module
		do
			start_test "Rmmod $module"
			echo "DEBUG: try $module"
			rmmod $module
			RET=$?
			if [ $RET -eq 0 ];then
				echo "$module" >> $MODULES_RM
				result 0 "rmmod-$module"
			else
				#result 1 "rmmod-$module"
				echo "DEBUG: fail to remove $module (ret=$RET)"
			fi
		done < $MODULES_LIST
		return 1
	else
		return 0
	fi
}

start_test "Load all modules"
#modprobe all
find /lib/modules -type f |grep kernel/ | sed 's,.*/,,' |
while read module
do
	echo "DEBUG: Load $module"
	#start_test "Load $module"
	modprobe $module
	#result $? "wifi-load-$wifi_module"
done
result 0 "test-module-load-all"


for i in $(seq 1 10)
do
	try_remove
	if [ $? -eq 0 ];then
		break
	fi
done

while read module
do
	start_test "Modprobe $module"
	echo "DEBUG: modprobe $module"
	modprobe $module
	if [ $? -ne 0 ];then
		echo "FAIL: $module"
		FINAL_CODE=1
		result 1 "modprobe-$module"
	else
		result 0 "modprobe-$module"
		#echo "DEBUG: modprobe $module ok"
	fi
done < $MODULES_RM

rm $MODULES_LIST
rm $MODULES_RM
exit $FINAL_CODE

