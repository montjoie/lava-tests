#!/bin/sh

. ./common

check_config DM_RAID
check_config MD_RAID0
check_config MD_RAID1
check_config MD_RAID456

fdisk -l |grep ^/

start_test "Check mdadm version"
mdadm --version
result $? "mdadm-version"

# find which disk are not used (filter LAVA test disk which seems to be always the latest)
mount

start_test "Check blkid version"
blkid --version
result $? "mdadm-blkid-version"

blkid | cut -d: -f1 | sed 's,/dev/,,' > $OUTPUT_DIR/blkid.filter

echo "=================="
echo "DEBUG: blkid filter"
cat $OUTPUT_DIR/blkid.filter
echo "=================="

ls /dev |grep -E 'sd[a-z]|vd[a-z]' | grep -vf $OUTPUT_DIR/blkid.filter > $OUTPUT_DIR/blklist
BLKNB=$(wc -l $OUTPUT_DIR/blklist)
echo "DEBUG: can test with $BLKNB devices"

while read sdev
do
	start_test "Partition $sdev"
	printf 'o\nn\np\n1\n\n\nw' | fdisk /dev/$sdev
	RET=$?
	echo "$sdev $RET"
	result $RET "mdadm-partition-$sdev"
done < $OUTPUT_DIR/blklist

find /dev -iname 'sd[a-z]1' -o -iname 'vd[a-z]1' | grep -vf $OUTPUT_DIR/blkid.filter > $OUTPUT_DIR/blklist

echo "======================"
echo "DEBUG: availlable partition"
cat $OUTPUT_DIR/blklist
echo "======================"

test_raid() {
	MDOPTS=""
	case $1 in
	raid1)
		RAID=raid1
		LEVEL=1
		RAID_NDEVS=3
		MDOPTS="--metadata=0.90"
	;;
	raid1-5)
		RAID=raid1w5
		LEVEL=1
		RAID_NDEVS=5
		MDOPTS="--metadata=0.90"
	;;
	raid5)
		RAID=raid5
		LEVEL=5
		RAID_NDEVS=3
	;;
	raid5-5)
		RAID=raid5
		LEVEL=5
		RAID_NDEVS=5
	;;
	raid6)
		RAID=raid6
		LEVEL=6
		RAID_NDEVS=4
	;;
	raid6-5)
		RAID=raid6w5
		LEVEL=6
		RAID_NDEVS=5
	;;
	*)
		echo "ERROR: unknow $1"
		return 1
	;;
	esac

	NDEVS_AVAIL=$(wc -l $OUTPUT_DIR/blklist)
	if [ $NDEVS_AVAIL -lt $RAID_NDEVS ];then
		echo "ERROR: not enough block devices"
	fi

	DEVLIST=""
	head -n $RAID_NDEVS $OUTPUT_DIR/blklist > $OUTPUT_DIR/blklist.$RAID_NDEVS
	while read sdev
	do
		DEVLIST="$sdev $DEVLIST"
	done < $OUTPUT_DIR/blklist.$RAID_NDEVS

	echo "DEBUG: DEVLIST=$DEVLIST"

	start_test "Create a $RAID"
	yes | mdadm --create /dev/md0 $MDOPTS --level=$LEVEL --raid-devices=$RAID_NDEVS --force $DEVLIST
	result $? "mdadm-$RAID-create"

	start_test "Show mdstat for $RAID"
	cat /proc/mdstat
	result $? "mdadm-$RAID-show"

	start_test "Format $RAID"
	mkfs.ext4 -F /dev/md0
	result $? "mdadm-$RAID-format"

	mkdir /test
	start_test "Mount $RAID"
	mount /dev/md0 /test
	result $? "mdadm-$RAID-mount"

	start_test "Create a file on $RAID"
	echo "12345" > /test/test
	result $? "mdadm-$RAID-file-create"

	DEVFAULT=$(head -n1 $OUTPUT_DIR/blklist.$RAID_NDEVS)
	start_test "Fault $DEVFAULT"
	mdadm --manage --set-faulty /dev/md0 $DEVFAULT
	result $? "mdadm-$RAID-fault"

	start_test "Recover $DEVFAULT"
	mdadm --manage /dev/md0 -r $DEVFAULT
	result $? "mdadm-$RAID-recover"

	start_test "Verify file on $RAID"
	cat /test/test
	result $? "mdadm-$RAID-file-verify"

	start_test "Umount $RAID"
	umount /dev/md0
	result $? "mdadm-$RAID-umount"

	start_test "Stop $RAID"
	mdadm --stop /dev/md0
	result $? "mdadm-$RAID-stop"

	#start_test "Remove $RAID"
	#mdadm --remove /dev/md0
	#result $? "mdadm-$RAID-remove"

	start_test "Zero $RAID"
	mdadm --zero-superblock $DEVLIST
	result $? "mdadm-$RAID-zero"
}

test_raid raid1
test_raid raid1-5
test_raid raid5
test_raid raid5-5
test_raid raid6
test_raid raid6-5
