#!/bin/sh

. ./common

check_config CONFIG_DM_CRYPT
if [ $? -ne 0 ];then
	echo "DEBUG: Missing CONFIG_DM_CRYPT"
fi
check_config CONFIG_CRYPTO_XTS
if [ $? -ne 0 ];then
	echo "DEBUG: Missing CONFIG_XTS"
fi

start_test "Check presence of cryptsetup"
cryptsetup --version
if [ $? -ne 0 ];then
	result SKIP "test-luks-cryptsetup"
	exit 0
fi

start_test "Generate fake image"
# create a fake volume
dd if=/dev/zero of=$OUTPUT_DIR/fake.img bs=1M count=10
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

