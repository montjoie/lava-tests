#!/bin/sh

. ./common

echo "======================================================"
mount
echo "======================================================"

install_portage() {
if [ -z "$PORTAGE_URL" ];then
	PORTAGE_URL="$2"
	echo "DEBUG: get PORTAGE_URL from parameter"
fi

# TODO grab proxy from a TXT DNS entry in lava.local
export http_proxy=192.168.1.40:3128
start_test "download portage"
#wget -q http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2
#wget -q http://boot.montjoie.local/portage-minimal.tar.bz2
wget -q "$PORTAGE_URL"
RET=$?
if [ $RET -ne 0 ];then
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
RET=$?
if [ $RET -ne 0 ];then
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
}

echo "DEBUG: prepare portage"
echo 'USE="-X -nls -acl -thin -btrfs -device-mapper -sodium -fortran -openmp -bindist caps"' >> /etc/portage/make.conf
#echo 'FEATURES="-distlocks noman nodoc"' >> /etc/portage/make.conf
echo 'FEATURES="noman nodoc"' >> /etc/portage/make.conf
# TODO un-hardcode thos
echo "http_proxy=192.168.1.40:3128" >> /etc/portage/make.conf
echo "MAKEOPTS=-j$(grep --count processor /proc/cpuinfo)" >> /etc/portage/make.conf
echo 'PORTDIR_OVERLAY="/usr/local/portage"' >> /etc/portage/make.conf

echo "======================================================"
echo "INFO: fix /lib/modules problem"
chown -c root:root /lib
chmod -c 755 /lib
echo "======================================================"

echo "INFO: compile on tmpfs"
mkdir -p /var/tmp/portage
mount -t tmpfs none /var/tmp/portage

MINDATE=1604989081
echo "INFO: check date"
CURRDATE=$(date +%s)
if [ $CURRDATE -le $MINDATE ];then
	echo "INFO: set date"
	date +%s -s "@$MINDATE"
	date
fi

start_test "Select profile"
SP_RESULT=0
case $(uname -m) in
x86_64)
	#ln -sf /usr/portage/profiles/default/linux/amd64/17.0 /etc/portage/make.profile
	eselect profile set default/linux/amd64/17.1
	SP_RESULT=$?
;;
armv7l)
	eselect profile set default/linux/arm/17.0/armv7a
	SP_RESULT=$?
;;
aarch64)
	eselect profile set default/linux/arm64/17.0
	SP_RESULT=$?
;;
*)
	echo "ERROR: cannot set profile, unknow arch $(uname -m)"
	eselect profile list
	SP_RESULT=fail
;;
esac
result $SP_RESULT "test-gentoo-select-profile"

start_test "Ran emerge info"
emerge --info
result $? "test-gentoo-emerge-info"

start_test "List GCC profile"
gcc-config -l
result $? "test-gentoo-gcc-config"

start_test "List binutils profiles"
eselect binutils list
result $? "test-gentoo-eselect-binutils"

start_test "Read all news"
eselect news read --quiet all
result $? "test-gentoo-news-read"

start_test "Purge news"
eselect news purge
result $? "test-gentoo-news-purge"

#start_test "Install ntp"
#emerge --nospinner --quiet --color n -v ntp -bk
#result $? "test-gentoo-install-ntp"

start_test "Install git"
emerge --nospinner --quiet --color n -v dev-vcs/git -bkp
emerge --nospinner --quiet --color n -v dev-vcs/git -bk
result $? "test-gentoo-install-git"

start_test "Install distcc"
emerge --nospinner --quiet --color n -v sys-devel/distcc -bkp
emerge --nospinner --quiet --color n -v sys-devel/distcc -bk
result $? "test-gentoo-install-distcc"

start_test "Install bc"
emerge --nospinner --quiet --color n -v sys-devel/bc -bkp
emerge --nospinner --quiet --color n -v sys-devel/bc -bk
result $? "test-gentoo-install-bc"

#start_test "Install nfs-utils"
#emerge --nospinner --quiet --color n -v nfs-utils -bk
#RET=$?
#if [ $RET -ne 0 ];then
#	result FAIL "test-gentoo-install-nfs-utils"
#	exit 0
#fi
#result 0 "test-gentoo-install-nfs-utils"

start_test "Deploy custom portage"
git clone --quiet https://github.com/montjoie/montjoiegentooportage.git /usr/local/portage
result $? "test-gentoo-local-portage"

start_test "Install cfengine"
USE="yaml lmdb -qdbm" emerge --nospinner --quiet --color n -v cfengine -bkp
USE="yaml lmdb -qdbm" emerge --nospinner --quiet --color n -v cfengine -bk
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-gentoo-install-cfengine"
	exit 0
fi
result 0 "test-gentoo-install-cfengine"

start_test "Create cfengine key"
cf-key
result $? "test-gentoo-cfengine-key"

echo "HACK: pre fix rigths on /var/db/pkg/"
chmod -R o-rwx /var/db/pkg/
chgrp -R portage /var/db/pkg/

start_test "Boot strap cfengine"
cf-agent -B 192.168.1.100
result $? "test-gentoo-cfengine-bootstrap"

start_test "Boot strap cfengine step 2"
cf-agent -K -I
result $? "test-gentoo-cfengine-bootstrap"

start_test "Boot strap cfengine step 3"
cf-agent -K -I
result $? "test-gentoo-cfengine-bootstrap3"

echo "============================"
/var/cfengine/modules/detect_network -d
echo "============================"
/var/cfengine/modules/detect_hw -d
echo "============================"
/var/cfengine/modules/dwh -d
echo "============================"

for dire in /var /home /var/cache /etc/portage
do
	echo "=================================== $dire"
	ls -la $dire
	echo "==================================="
done

start_test "Install some pkgs"
emerge --nospinner --quiet --color n -v ntp lsof cronie lm-sensors gentoolkit gemato portage openssh openssl -Nbkp
emerge --nospinner --quiet --color n -v ntp lsof cronie lm-sensors gentoolkit gemato portage openssh openssl -bk
result $? "test-gentoo-install-pkgs"

start_test "pretend upgrade"
emerge --nospinner --quiet --color n -v -bkpDNu world
result $? "test-gentoo-upgrade"


exit 0

start_test "mount portage"
mount -t nfs -o ro,tcp,hard,intr,async,vers=3 192.168.1.100:/usr/portage/ /usr//portage/
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-mount-portage"
	exit 0
fi
result 0 "test-mount-portage"

start_test "mount local portage"
mount -t nfs -o ro,tcp,hard,intr,async,vers=3 192.168.1.100:/usr/local/portage/ /usr/local/portage/
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-mount-local-portage"
	exit 0
fi
result 0 "test-mount-local-portage"

start_test "mount portage distfiles"
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 192.168.1.100:/mnt/tempo/portages/distfiles/ /usr/portage/distfiles/
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-mount-portage-distfiles"
	exit 0
fi
result 0 "test-mount-portage-distfiles"

start_test "mount portage packages"
mount -t nfs -o rw,tcp,hard,intr,async,vers=3 "192.168.1.100:/mnt/tempo/portages/$(uname -m)/packages/" /usr/portage/packages/
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-mount-portage-packages"
	exit 0
fi
result 0 "test-mount-portage-packages"

start_test "Install ethtool"
emerge --nospinner --quiet --color n -v ethtool
RET=$?
if [ $RET -ne 0 ];then
	result FAIL "test-gentoo-install-ethtool"
	exit 0
fi
result 0 "test-gentoo-install-ethtool"

