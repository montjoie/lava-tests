#!/bin/sh

. ./common

fdisk -l |grep ^/
fdisk -l |grep ^/ | cut -d' ' -f1 > $OUTPUT_DIR/storage-list
if [ -s $OUTPUT_DIR/storage-list ];then
	while read tdev
	do
		start_test "Read $tdev via dd"
		dd if=$tdev of=/dev/null bs=1M count=50
		result $? "storage-dd-$tdev"
	done < $OUTPUT_DIR/storage-list
else
	result SKIP "storage"
fi
exit 0

