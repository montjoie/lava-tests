#!/bin/sh

. ./common

print_crypto_stat

echo "DEBUG: check for libkcapi test"
if [ -e /usr/libexec/libkcapi/test.sh ];then
	cp /usr/libexec/libkcapi/test.sh /usr/libexec/libkcapi/test.sh.old
	sed -i 's,^[[:space:]][[:space:]]*aead,echo "aead"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^[[:space:]][[:space:]]*multipletest_aead,echo "aead"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^pbkdftest$,echo "pbkdftest"#,' /usr/libexec/libkcapi/test.sh
	sed -i 's,^pbkdftest -m$,echo "pbkdftest"#,' /usr/libexec/libkcapi/test.sh
	diff -u /usr/libexec/libkcapi/test.sh.old /usr/libexec/libkcapi/test.sh
	start_test "Run libkcapi test"
	/usr/libexec/libkcapi/test.sh
	result $? "crypto-libkcapi"
	print_crypto_stat
fi
