#!/bin/sh

echo "TOOLCHAIN"
for toolchain in armv7a-unknown-linux-gnueabihf/gcc-bin/9.2.0/ armv7a-unknown-linux-gnueabihf/binutils-bin/2.33.1/
do
	if [ -e /usr/$toolchain ];then
		echo "DEBUG: add $toolchain"
		#export PATH=/usr/$toolchain:$PATH
		#ls -l /usr/$toolchain
	else
		echo "DEBUG: /usr/$toolchain does not exists"
	fi
done
echo "PATH:"
echo $PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

#cd /lib
#ln -s /lib/ld-2.30.so /lib/ld-linux-armhf.so.3

echo "VERIFY GCC"
ldd /usr/armv7a-unknown-linux-gnueabihf/gcc-bin/9.2.0/armv7a-unknown-linux-gnueabihf-gcc
gcc --version
armv7a-unknown-linux-gnueabihf-gcc --version

echo "
#include <stdlib.h>
int main() { return 0; }
" > test.c
echo "COMPILE"
armv7a-unknown-linux-gnueabihf-gcc test.c -o bob
echo $?

echo "VERIFY BINUTILS"
ldd /usr/armv7a-unknown-linux-gnueabihf/binutils-bin/2.33.1/armv7a-unknown-linux-gnueabihf-as
as --version
armv7a-unknown-linux-gnueabihf-as --version

echo "DISTCC UPDATE"
/usr/sbin/update-distcc-symlinks

echo "DISTCC VERIFY"
ls -l /usr/lib/distcc
ls -l /usr/lib64/distcc

echo "MISC"
cc1 --version
echo $?
pwd

echo "RUN distcc"
#/usr/bin/distccd --daemon --make-me-a-botnet --log-stderr --allow 192.168.1.0/24 --enable-tcp-insecure --verbose --port 3632 --log-level=debug
#/usr/bin/distccd --no-detach --make-me-a-botnet --log-stderr --allow 192.168.1.0/24 --enable-tcp-insecure --verbose --port 3632
sleep 2
#ps aux
netstat -lpn

sleep 1000000000000
sleep 100000000000
sleep 10000000000
sleep 1000000000
sleep 100000000

echo "RUN distcc client"
/opt/distcc.py --serveur 192.168.1.22 --netport 15154
