#!/bin/sh

. ./common

check_config DM_CRYPT
if [ $? -ne 0 ];then
	echo "DEBUG: Missing CONFIG_DM_CRYPT"
fi
check_config CRYPTO_XTS
if [ $? -ne 0 ];then
	echo "DEBUG: Missing CONFIG_XTS"
fi

start_test "Check presence of cryptsetup"
cryptsetup --version
if [ $? -ne 0 ];then
	result SKIP "test-luks-cryptsetup"
	exit 0
fi

start_test "cryptsetup benchmark"
cryptsetup benchmark > $OUTPUT_DIR/cryptsetup-benchmark
result $RET "test-luks-cryptsetup-benchmark"
cat $OUTPUT_DIR/cryptsetup-benchmark
#TODO analysis of output

start_test "Generate fake image"
# create a fake volume
dd if=/dev/zero of=$OUTPUT_DIR/fake.img bs=1M count=100
RET=$?
result $RET "test-luks-generate-img"
if [ $RET -ne 0 ];then
	exit 0
fi

echo 'toto' >$OUTPUT_DIR/fake.key

start_test "crytpsetup format"
cryptsetup --key-file=$OUTPUT_DIR/fake.key --batch-mode luksFormat $OUTPUT_DIR/fake.img
RET=$?
result $RET "test-luks-format-img"
if [ $RET -ne 0 ];then
	exit 0
fi

start_test "crytpsetup open"
cryptsetup --key-file=$OUTPUT_DIR/fake.key --batch-mode luksOpen $OUTPUT_DIR/fake.img fake
RET=$?
result $RET "test-luks-open"
if [ $RET -ne 0 ];then
	exit 0
fi

start_test "crytpsetup status"
cryptsetup status /dev/mapper/fake
result $RET "test-luks-status"

start_test "mkfs"
mkfs.ext4 /dev/mapper/fake
RET=$?
result $RET "test-luks-mkfs"
if [ $RET -ne 0 ];then
	exit 0
fi

mkdir /mnt/luks
start_test "crytpsetup mount"
mount /dev/mapper/fake /mnt/luks
RET=$?
result $RET "test-luks-mount"
if [ $RET -ne 0 ];then
	exit 0
fi

start_test "cryptsetup bench the disk"
dd if=/dev/zero of=/mnt/luks/test oflag=sync bs=1M count=50
result $RET "test-luks-bench"

start_test "crytpsetup umount"
umount /mnt/luks
RET=$?
result $RET "test-luks-umount"
if [ $RET -ne 0 ];then
	exit 0
fi

start_test "crytpsetup close"
cryptsetup luksClose fake
RET=$?
result $RET "test-luks-format-close"
if [ $RET -ne 0 ];then
	exit 0
fi

rm $OUTPUT_DIR/fake.img

test_pluks()
{
LUKSMAX=$1
FLAG="oflag=sync"
DDMODE="sync"
CREATE_OPTS="--type luks2 --sector-size=4096 --size=4096"
case $2 in
async)
	FLAG=""
	DDMODE="async"
;;
async2)
	FLAG="oflag=nonblock"
	DDMODE="async2"
;;
*)
	FLAG="oflag=sync"
;;
esac
for luksid in $(seq 1 $LUKSMAX)
do
	start_test "Generate fake image $luksid"
	dd if=/dev/zero of=$OUTPUT_DIR/fake${luksid}.img bs=1M count=100
	RET=$?
	result $RET "test-pluks-generate-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	echo "key$luksid" >$OUTPUT_DIR/fake${luksid}.key

	start_test "crytpsetup format image$luksid"
	cryptsetup --key-file=$OUTPUT_DIR/fake${luksid}.key --batch-mode $CREATE_OPTS luksFormat $OUTPUT_DIR/fake${luksid}.img
	RET=$?
	result $RET "test-pluks-format-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	start_test "crytpsetup open image${luksid}"
	cryptsetup --key-file=$OUTPUT_DIR/fake${luksid}.key --batch-mode luksOpen $OUTPUT_DIR/fake${luksid}.img fake${luksid}
	RET=$?
	result $RET "test-pluks-open-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	start_test "crytpsetup status image${luksid}"
	cryptsetup status /dev/mapper/fake${luksid}
	result $RET "test-pluks-status-img${luksid}-${LUKSMAX}-${DDMODE}"

	start_test "mkfs LUKS image${luksid}"
	mkfs.ext4 /dev/mapper/fake${luksid}
	RET=$?
	result $RET "test-pluks-mkfs-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	mkdir /mnt/luks${luksid}
	start_test "crytpsetup mount image${luksid}"
	mount /dev/mapper/fake${luksid} /mnt/luks${luksid}
	RET=$?
	result $RET "test-pluks-mount-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi
done


	start_test "cryptsetup bench the disk in parallel on $LUKSMAX images mode=$DDMODE"
	for luksid in $(seq 1 $LUKSMAX)
	do
		dd if=/dev/zero of=/mnt/luks${luksid}/test $FLAG bs=256k count=200 &
	done
	wait
	result $RET "test-pluks-bench-${LUKSMAX}-${DDMODE}"

	start_test "cryptsetup readbench the disk in parallel on $LUKSMAX images mode=$DDMODE"
	for luksid in $(seq 1 $LUKSMAX)
	do
		dd if=/mnt/luks${luksid}/test of=/dev/null $FLAG bs=256k count=200 &
	done
	wait
	result $RET "test-pluks-readbench-${LUKSMAX}-${DDMODE}"


for luksid in $(seq 1 $LUKSMAX)
do
	start_test "crytpsetup umount image${luksid}"
	umount /mnt/luks${luksid}
	RET=$?
	result $RET "test-pluks-umount-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	start_test "crytpsetup close image${luksid}"
	cryptsetup luksClose fake${luksid}
	RET=$?
	result $RET "test-pluks-format-close-img${luksid}-${LUKSMAX}-${DDMODE}"
	if [ $RET -ne 0 ];then
		return 0
	fi

	rm $OUTPUT_DIR/fake${luksid}.img
done
}

print_crypto_stat
test_pluks 2
print_crypto_stat
test_pluks 4
print_crypto_stat
test_pluks 2 async
print_crypto_stat
test_pluks 4 async
print_crypto_stat
test_pluks 2 async2
print_crypto_stat
test_pluks 4 async2
print_crypto_stat
