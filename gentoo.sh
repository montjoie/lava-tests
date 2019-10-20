#!/bin/sh

. ./common

echo "======================================================"
mount
echo "======================================================"

if [ -z $PORTAGE_URL ];then
	PORTAGE_URL="$2"
	echo "DEBUG: get PORTAGE_URL from parameter"
fi

# TODO grab proxy from a TXT DNS entry in lava.local
export http_proxy=192.168.1.40:3128
start_test "download portage"
#wget -q http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2
#wget -q http://boot.montjoie.local/portage-minimal.tar.bz2
wget -q $PORTAGE_URL
if [ $? -ne 0 ];then
	result FAIL "test-download-portage"
	exit 0
fi
result 0 "test-download-portage"

PORTAGE_IN_VAR_DB=0
T_PORTAGE_DIR=/usr/

if [ $PORTAGE_IN_VAR_DB -eq 1 ];then
	mkdir -p /var/db/repos/gentoo
	T_PORTAGE_DIR=/var/db/repos/gentoo
fi

start_test "extract portage"
#tar xjf portage-latest.tar.bz2 -C /usr/ --wildcards '*net-fs/nfs-utils*' '*net-libs/libtirpc*' '*net-nds/rpcbind*' '*sys-apps/keyutils*' '*eclass/*' '*metadata/*' '*profiles/*'
tar xjf portage-minimal.tar.bz2 -C $T_PORTAGE_DIR 2>/dev/null >/dev/null
if [ $? -ne 0 ];then
	result FAIL "test-extract-portage"
	exit 0
fi
result 0 "gentoo-extract-portage"

if [ -e /var/db/repos/gentoo/portage ];then
	mv /var/db/repos/gentoo/portage/* /var/db/repos/gentoo/
	rmdir /var/db/repos/gentoo/portage
	#rm -r /usr/portage
	#ln -s /var/db/repos/gentoo/ /usr/portage
fi

echo "DEBUG: prepare portage"
echo 'USE="-X -nls -acl -thin -btrfs -device-mapper -sodium -fortran -openmp -bindist"' >> /etc/portage/make.conf
#echo 'FEATURES="-distlocks noman nodoc"' >> /etc/portage/make.conf
echo 'FEATURES="noman nodoc"' >> /etc/portage/make.conf
echo "http_proxy=192.168.1.40:3128" >> /etc/portage/make.conf
echo "MAKEOPTS=-j$(grep processor /proc/cpuinfo | wc -l)" >> /etc/portage/make.conf
echo 'PORTDIR_OVERLAY="/usr/local/portage"' >> /etc/portage/make.conf

echo "======================================================"
chown -c root:root /lib
chmod -c 755 /lib
echo "======================================================"

start_test "Select profile"
SP_RESULT=0
case $(uname -m) in
x86_64)
	#ln -sf /usr/portage/profiles/default/linux/amd64/17.0 /etc/portage/make.profile
	eselect profile set default/linux/amd64/17.1
;;
armv7l)
	eselect profile set default/linux/arm/17.0/armv7a
;;
*)
	echo "ERROR: cannot set profile, unknow arch $(uname -m)"
	eselect profile list
	SP_RESULT=fail
;;
esac
result $SP_RESULT "test-gentoo-select-profile"

mkdir -p /usr/portage/packages
mkdir -p /usr/portage/distfiles
chown portage /usr/portage/distfiles

#mkdir /var/db/repos/gentoo/distfiles/
#chown portage /var/db/repos/gentoo/distfiles/

#mkdir /tmp/tomove
#mv /var/log/* /tmp/tomove/
#mount -t tmpfs none /var/log/
#mv /tmp/tomove/* /var/log/

start_test "Ran emerge info"
emerge --info
result $? "test-gentoo-emerge-info"

start_test "Install nfs-utils"
emerge --nospinner --quiet --color n -v nfs-utils
if [ $? -ne 0 ];then
	result FAIL "test-gentoo-install-nfs-utils"
	exit 0
fi
result 0 "test-gentoo-install-nfs-utils"

start_test "mount portage"
mount -t nfs -o ro,tcp,hard,intr,async,vers=3 192.168.1.100:/usr/portage/ /usr//portage/
if [ $? -ne 0 ];then
	result FAIL "test-mount-portage"
	exit 0
fi
result 0 "test-mount-portage"

start_test "mount local portage"
mount -t nfs -o ro,tcp,hard,intr,async,vers=3 192.168.1.100:/usr/local/portage/ /usr/local/portage/
if [ $? -ne 0 ];then
	result FAIL "test-mount-local-portage"
	exit 0
fi
result 0 "test-mount-local-portage"

start_test "mount portage distfiles"
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 192.168.1.100:/mnt/tempo/portages/distfiles/ /usr/portage/distfiles/
if [ $? -ne 0 ];then
	result FAIL "test-mount-portage-distfiles"
	exit 0
fi
result 0 "test-mount-portage-distfiles"

start_test "mount portage packages"
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 192.168.1.100:/mnt/tempo/portages/$(uname -m)/packages/ /usr/portage/packages/
if [ $? -ne 0 ];then
	result FAIL "test-mount-portage-packages"
	exit 0
fi
result 0 "test-mount-portage-packages"

start_test "Install ethtool"
emerge --nospinner --quiet --color n -v ethtool
if [ $? -ne 0 ];then
	result FAIL "test-gentoo-install-ethtool"
	exit 0
fi
result 0 "test-gentoo-install-ethtool"

start_test "Install cfengine"
USE="yaml" emerge --nospinner --quiet --color n -v cfengine
if [ $? -ne 0 ];then
	result FAIL "test-gentoo-install-cfengine"
	exit 0
fi
result 0 "test-gentoo-install-cfengine"

start_test "Boot strap cfengine"
cf-agent -B 192.168.1.100
result $? "test-gentoo-cfengine-bootstrap"

start_test "Boot strap cfengine step 2"
cf-agent -K -I
result $? "test-gentoo-cfengine-bootstrap"

start_test "Boot strap cfengine step 3"
cf-agent -K -I
result $? "test-gentoo-cfengine-bootstrap3"

