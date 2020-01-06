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
			start_test "Rmmod $module"
			grep -q "^$module$" modules.remove.blacklist
			if [ $? -eq 0 ];then
				result SKIP "rmmod-$module"
				continue
			fi
			echo $module | grep -qE 'thunderx2_pmu|arm_smmuv3_pmu|pcrypt'
			if [ $? -eq 0 ];then
				result SKIP "rmmod-$module"
				continue
			fi
			echo $module | grep -qE 'nbd'
			if [ $? -eq 0 ];then
				echo "DEBUG: spetial hack for $module"
				echo "#!/bin/sh
					rmmod $module &
					PID=\$!
					wait \$PID
					touch OUTPUT_DIR/rmmod.end
				" > $OUTPUT_DIR/rmmod.sh
				echo "===================="
				cat $OUTPUT_DIR/rmmod.sh
				echo "===================="
				chmod +x $OUTPUT_DIR/rmmod.sh
				$OUTPUT_DIR/rmmod.sh&
				PID=$!
				timeelapsed=0
				while [ $timeelapsed -le 60 ]
				do
					if [ -e $OUTPUT_DIR/rmmod.end ];then
						break
					fi
					sleep 1
					timeelapsed=$(($timeelapsed+1))
				done
				if [ $timeelapsed -ge 120 ];then
					kill $PID
					echo "ERROR: rmmod $module timeout!"
					RET=1
					dmesg
					ps aux
				else
					RET=0
					echo "DEBUG: rmmod exit ret=$RET after $timeelapsed seconds"
				fi
				result 1 "rmmod-$module"
				continue
			fi
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
		echo "================================================"
		echo "DEBUG: remaining modules"
		lsmod
		echo "================================================"
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
	start_test "Load $module"
	modprobe $module 2> $OUTPUT_DIR/modprobe.err
	RET=$?
	echo "DEBUG: ret=$RET"
	grep -Ei 'no such device' $OUTPUT_DIR/modprobe.err
	if [ $? -eq 0 ];then
		RET=0
	fi
	if [ $module == 'tcrypt' ];then
		RET=0
	fi
	result $RET "load-$module"
done
#result 0 "test-module-load-all"


for i in $(seq 1 10)
do
	echo "INFO: Removing modules step $i"
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
	RET=$?
	if [ $RET -ne 0 ];then
		echo "FAIL: $module ret=$RET"
		RET=1
	fi
	result $RET --sleep 2 "modprobe-$module"
done < $MODULES_RM

rm $MODULES_LIST
rm $MODULES_RM
exit $FINAL_CODE

