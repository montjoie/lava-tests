#!/bin/sh

. ./common

export COLUMNS=200
export TERM=dumb

echo "======================================================"
mount
echo "======================================================"

selinux_load_modules() {
	start_test "install selinux pkg cfengine"
	emerge -pvbk1 selinux-cfengine selinux-bind selinux-smartmon
	emerge -vbk1 selinux-cfengine selinux-bind selinux-smartmon
	result $? "test-gentoo-selinux-modules-install"

	start_test "List current modules"
	semodule -l
	result $? "test-gentoo-selinux-modules-list"

	SE_POLTYPE=$(grep ^SELINUXTYPE= /etc/selinux/config | cut -d\= -f2 | cut -d\  -f1)
	echo "DEBUG: politique $SE_POLTYPE"
	semod="/usr/share/selinux/$SE_POLTYPE/cfengine.pp"
	if [ -e "$semod" ];then
		start_test "Load SELinux module cfengine"
		semodule -i "$semod"
		result $? "test-gentoo-selinux-modules-cfengine"
	else
		echo "DEBUG: $semod does not exists"
	fi
}

selinux_load_custom() {
	if [ ! -e /opt/selinux/ ];then
		git clone --quiet https://github.com/montjoie/selinux.git /opt/selinux
	fi
	if [ ! -e /opt/selinux/ ];then
		echo "INFO: /opt/selinux/ does not exists, skipping"
		return
	fi
	cd /opt/selinux/
	SE_POLTYPE=$(grep ^SELINUXTYPE= /etc/selinux/config | cut -d\= -f2 | cut -d\  -f1)
	echo "DEBUG: politique $SE_POLTYPE"
	SE_MAKEFILE="/usr/share/selinux/$SE_POLTYPE/include/Makefile"
	echo "DEBUG: use $SE_MAKEFILE"
	start_test "Compile custom SELinux policies"
	make -f $SE_MAKEFILE
	result $? "test-gentoo-selinux-compile-custom"

	ls *te | while read sete
	do
		sepp=${sete/.te/.pp}
		echo "DEBUG: load $sepp"
		start_test "Load custome module $sepp"
		semodule -i $sepp
		result $? "test-gentoo-selinux-load-$sepp"
	done
}

selinux_login_user() {
	semanage login -l
	semanage user -l
	semanage user -m -R system_r -R unconfined_r unconfined_u
	semanage user -l
}

select_profile() {
	start_test "Select profile"
	SP_RESULT=0
	case $(uname -m) in
	x86_64)
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
}


echo "DEBUG: prepare portage"
echo 'USE="-X -nls -acl -thin -btrfs -device-mapper -sodium -fortran -openmp -bindist caps sqlite -gdbm"' >> /etc/portage/make.conf
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

MINDATE=1608795693
echo "INFO: check date"
CURRDATE=$(date +%s)
if [ $CURRDATE -le $MINDATE ];then
	echo "INFO: set date"
	date +%s -s "@$MINDATE"
	date
fi

SELINUX=0
echo "=================== CURRENT PROFILE"
eselect profile show
echo "==================="

eselect profile show |grep -q selinux
if [ $? -eq 0 ];then
	echo "DEBUG: running with selinux"
	SELINUX=1
	start_test "Set SELinux boolean portage_use_nfs"
	setsebool portage_use_nfs 1
	result $? "gentoo-selinux-bool-portage_use_nfs"
	selinux_load_modules
	selinux_load_custom
	selinux_login_user
	touch /var/log/lastlog
	# TODO
	mkdir /var/cache/cfengine
	echo "=============== restorecon post init"
	restorecon -Rx /
	echo "===================================="
fi

if [ $SELINUX -eq 0 ];then
	select_profile
fi

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

start_test "Check exported variables"
export
echo "DO_DISTCC: $DO_DISTCC"
echo "DO_XFS: $DO_XFS"
echo "DO_GUEST: $DO_GUEST"
result $? "test-gentoo-export"

echo "INFO: check accept keywords"
if [ -e /etc/portage/package.accept_keywords ];then
	if [ ! -d /etc/portage/package.accept_keywords ];then
		echo "DEBUG: convert package.accept_keywords to directory"
		mv /etc/portage/package.accept_keywords /etc/portage/package.accept_keywords2
		mkdir /etc/portage/package.accept_keywords
		mv /etc/portage/package.accept_keywords2 /etc/portage/package.accept_keywords/old
	fi
else
	mkdir /etc/portage/package.accept_keywords
fi
echo "============================== package.mask"
if [ -e /etc/portage/package.mask ];then
	if [ ! -d /etc/portage/package.mask ];then
		echo "DEBUG: convert package.mask to directory"
		mv /etc/portage/package.mask /etc/portage/package.mask2
		mkdir /etc/portage/package.mask
		mv /etc/portage/package.mask2 /etc/portage/package.mask/old
	fi
fi
echo "=sys-devel/gcc-8.4.0-r1" >> /etc/portage/package.mask/gcc
echo "=sys-devel/gcc-9.3.0-r1" >> /etc/portage/package.mask/gcc
echo "=sys-devel/gcc-9.3.0-r2" >> /etc/portage/package.mask/gcc
echo "sys-devel/gcc" >> /etc/portage/package.mask/gcc
echo "=============================="

echo "INFO: verify PKGDIR"
PKGDIR=$(grep ^PKGDIR /etc/portage/make.conf)
if [ -z "$PKGDIR" ];then
	echo "INFO: no PKGDIR in /etc/portage/make.conf"
	if [ -e /var/cache/binpkgs ];then
		PKGDIR='/var/cache/binpkgs'
		echo "DEBUG: fallback to $PKGDIR"
	fi
else
	echo "FOUND $PKGDIR"
	PKGDIR=$(grep ^PKGDIR /etc/portage/make.conf | cut -d= -f2)
	echo "FOUND $PKGDIR"
	PKGDIR=$(grep ^PKGDIR /etc/portage/make.conf | cut -d= -f2 | sed 's,\\,,g' | sed 's,",,g' )
	echo "FOUND $PKGDIR"
	echo "=============================="
	ls -l $PKGDIR
	echo "=============================="
	ls -lZ $PKGDIR/
fi
echo "============================== /var/cache"
ls -l /var/cache
echo "=============================="
if [ -e /usr/portage/packages ];then
	echo "INFO: /usr/portage/packages exists"
	ls -l /usr/portage/ |grep packages
fi

if [ $SELINUX -eq 1 ];then
	sestatus
	emerge -pv1 audit
	echo "DEBUG: verify context ===================== ls /"
	ls -lZ /
	echo "============================== ps"
	ps auxZ
	echo "============================== id"
	id -Z
	echo "=============================="
fi

if [ -e /etc/init.d/sshd ];then
	echo "DEBUG: deploy my ssh"
	mkdir /root/.ssh
	echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAoc7EVHs/ikiszgCkurrwt0Yb5mKMeK/g54DtIPPjX4Doa5pVAqKAr80CLgD4asKwMSs4kaYWwldHON4wP0KINDlYvTdGe7cdrsf/wwilC1eH81NqzF3GwHSF+9CWjggZpR/vgqWcE6KmEhdhXrPlFOJYnB3uS91dPj1VtxB/87SyonyJWvIZk+wSmW+XlYvoSXR8xImIF/WNdxNsIoLykCYQ/LmNlR0Ly/5XChPl0bOogU/nFqvFigt+Blg8Kq05YggZwHFtsMcRIcB+SE9biVh/RkYdirzeoyaXBJP7XhT4nb5zyEjG/SI5o3/2D3nY9TyDgKSZeq5Mq0W18midgw== montjoie@Red" > /root/.ssh/authorized_keys
	#/etc/init.d/sshd start
	echo "============================"
else
	echo "DEBUG: cannot deploy ssh keys"
fi

start_test "Install ntp"
emerge --nospinner --quiet --color n -v ntp -bkp
emerge --nospinner --quiet --color n -v ntp -bk
result $? "test-gentoo-install-ntp"

start_test "Sync on ntp"
if [ $SELINUX -eq 1 ];then
	echo bob | run_init /etc/init.d/ntp-client restart
else
	/etc/init.d/ntp-client restart
fi
result $? "test-gentoo-ntp-client"

start_test "Install git"
emerge --nospinner --quiet --color n -v dev-vcs/git -bkp
#try_run -t 600 -se ps -S 30 emerge --nospinner --quiet --color n -v dev-vcs/git -bk
emerge --nospinner --quiet --color n -v dev-vcs/git -bk
result $? "test-gentoo-install-git"

if [ ! -e /usr/local/portage ];then
	start_test "Deploy custom portage"
	git clone --quiet https://github.com/montjoie/montjoiegentooportage.git /usr/local/portage
	result $? "test-gentoo-local-portage"
else
	echo "SKIP: /usr/local/portage already exists"
fi

if [ $SELINUX -eq 1 ];then
	selinux_load_custom
fi

start_test "Upgrade python"
emerge --nospinner --quiet --color n -1Dv python:2.7 python-exec -bkp
emerge --nospinner --quiet --color n -1Dv python:2.7 python-exec -bk
result $? "test-gentoo-python-upgrade"

if [ "$DO_DISTCC" = 'yes' ];then
	start_test "Install distcc"
	emerge --nospinner --quiet --color n -v sys-devel/distcc -bkp
	emerge --nospinner --quiet --color n -v sys-devel/distcc -bk
	result $? "test-gentoo-install-distcc"
fi

start_test "Install bc"
emerge --nospinner --quiet --color n -v sys-devel/bc -bkp
emerge --nospinner --quiet --color n -v sys-devel/bc -bk
result $? "test-gentoo-install-bc"

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
echo "============================ keywords"
ls -l /etc/portage
for keywor in $(ls /etc/portage/package.accept_keywords/)
do
	echo "============ $keywor"
	cat /etc/portage/package.accept_keywords/$keywor
done
echo "============================ package.env"
for keywor in $(ls /etc/portage/package.env/)
do
	echo "============ $keywor"
	cat /etc/portage/package.env/$keywor
done
echo "============================ env"
for keywor in $(ls /etc/portage/env/)
do
	echo "============ $keywor"
	cat /etc/portage/env/$keywor
done
echo "============================"

for dire in /var /home /var/cache /etc/portage
do
	echo "=================================== $dire"
	ls -la $dire
	echo "==================================="
done

if [ "$(uname -m)" = 'x86_64' ];then
	df -h
	echo "=app-emulation/libguestfs-1.38.6-r100 * **" >> /etc/portage/package.accept_keywords/libguestfs
	echo "app-emulation/libguestfs-appliance ~amd64" >> /etc/portage/package.accept_keywords/libguestfs
	echo "dev-ml/ocaml-gettext ~amd64" >> /etc/portage/package.accept_keywords/libguestfs
	echo "dev-ml/ocaml-fileutils ~amd64" >> /etc/portage/package.accept_keywords/libguestfs
	echo "app-misc/hivex ~amd64" >> /etc/portage/package.accept_keywords/libguestfs
	echo "dev-ml/base ~amd64" >> /etc/portage/package.accept_keywords/libguestfs
	echo "app-emulation/qemu -png -jpeg" >> /etc/portage/package.use/qemu
	start_test "Install libguestfs"
	USE="natspec python -perl -ocaml -libvirt -fuse" emerge --nospinner --quiet --color n -v libguestfs -bkp
	USE="natspec python -perl -ocaml -libvirt -fuse" emerge --nospinner --quiet --color n -v libguestfs -bk
	result $? "test-gentoo-install-libguestfs"
fi

start_test "Install some pkgs"
emerge --nospinner --quiet --color n -v gentoolkit gemato portage openssh openssl -Nbkp
emerge --nospinner --quiet --color n -v gentoolkit gemato portage openssh openssl -bk
result $? "test-gentoo-install-pkgs"

if [ "$(uname -m)" = 'aarch64' ];then
	echo "sys-fs/xfstests **" >> /etc/portage/package.accept_keywords/xfstests
	start_test "Install xfstests"
	emerge --nospinner --quiet --color n -v xfstests -bkp
	emerge --nospinner --quiet --color n -v xfstests -bk
	result $? "test-gentoo-install-xfstests"
fi

myquickpkg() {
	find $PKGDIR |grep -q $1
	if [ $? -eq 0 ];then
		echo "DEBUG: skip quickpkg for $1"
	else
		quickpkg --include-config=y $1
	fi
}

if [ "$(uname -m)" = 'armv7l' ];then
	#myquickpkg sys-libs/readline
	#myquickpkg sys-devel/gcc
	#myquickpkg sys-devel/binutils
	#myquickpkg net-dns/libidn2
	#myquickpkg dev-python/certifi
	#myquickpkg dev-python/setuptools
	start_test "pretend upgrade glibc"
	emerge --nospinner --quiet --color n -v -pvbk1 glibc
	emerge --nospinner --quiet --color n -v -vbk1 glibc
	result $? "test-gentoo-upgrade-glibc"

	mkdir /etc/portage/env/
	mkdir /etc/portage/package.env/
	echo 'MAKEOPTS="-j4"' > /etc/portage/env/lesscpu.conf
	echo 'sys-devel/binutils lesscpu.conf' > /etc/portage/package.env/lesscpu
	start_test "pretend upgrade binutils"
	emerge --nospinner --quiet --color n -v -pvbk1 binutils
	emerge --nospinner --quiet --color n -v -vbk1 binutils
	result $? "test-gentoo-upgrade-binutils"

	echo "DEBUG:========== dump /etc/portage/make.conf"
	cat /etc/portage/make.conf
	echo "========================================="

	start_test "select latest binutils"
	eselect binutils list
	G_CHOST=$(grep '^CHOST=' /etc/portage/make.conf | cut -d'"' -f2)
	echo "DEBUG: current CHOST=$G_CHOST"
	eselect binutils list |grep $G_CHOST | tail -n1
	echo "DEBUG: ======================"
	BIN_SLOT=$(eselect binutils list |grep $G_CHOST | tail -n1 | cut -d'[' -f2 | cut -d']' -f1)
	echo "DEBUG: use $BIN_SLOT"
	eselect binutils set $BIN_SLOT
	result $? "test-gentoo-select-binutils"

	start_test "pretend upgrade perl"
	emerge --nospinner --quiet --color n -v -pvbk1 perl
	emerge --nospinner --quiet --color n -v -vbk1 perl
	result $? "test-gentoo-upgrade-perl"

	start_test "perl-cleaner"
	perl-cleaner --all -p -v -- -k
	result $? "test-gentoo-perl-cleaner"

	start_test "pretend upgrade last python"
	emerge --nospinner --quiet --color n -v -puvbk1 python
	emerge --nospinner --quiet --color n -v -vubk1 python
	result $? "test-gentoo-upgrade-python-last"

	echo "==================================="
	echo "DEBUG: generate all python packages"
	ALL_PY=""
	equery -C l -F '$cp' 'dev-python/*' > $OUTPUT_DIR/allpython
	cat $OUTPUT_DIR/allpython
	echo "==================================="
	while read pyth
	do
		ALL_PY="$ALL_PY $pyth"
	done < $OUTPUT_DIR/allpython

	echo "DEBUG: all python are $ALL_PY"
	echo "==================================="

	start_test "pretend upgrade all python"
	emerge --nospinner --quiet --color n -v -puvbk1 $ALL_PY
	emerge --nospinner --quiet --color n -v -vbk1u $ALL_PY
	result $? "test-gentoo-upgrade-python-all"

	#start_test "install cifs-utils"
	#emerge --nospinner --quiet --color n -v -puvbk1 cifs-utils libpcre libpcre2 bash util-linux lvm2 libxml2 slang gawk readline
	#emerge --nospinner --quiet --color n -v -uvbk1 cifs-utils libpcre libpcre2 bash util-linux lvm2 libxml2 slang gawk readline
	#result $? "test-gentoo-install-cifs-utils"

	#start_test "install rsyslog"
	#USE="ssl openssl" emerge --nospinner --quiet --color n -v -puvbk1 rsyslog
	#USE="ssl openssl" emerge --nospinner --quiet --color n -v -uvbk1 rsyslog
	#result $? "test-gentoo-install-rsyslog"

	#start_test "install misc"
	#emerge --nospinner --quiet --color n -v -pvbk1 lvm2 python:3.6 gawk readline util-linux virtual/libcrypt sys-apps/man-pages iputils lxml cython meson virtual/ssh app-misc/mc smartmontools openvpn hddtemp sys-apps/watchdog logrotate strace cryptsetup postfix vim app-misc/screen xz-utils hdparm diffutils gzip which
	#emerge --nospinner --quiet --color n -v -vbk1 lvm2 python:3.6 gawk util-linux virtual/libcrypt sys-apps/man-pages iputils lxml cython meson virtual/ssh app-misc/mc smartmontools openvpn hddtemp sys-apps/watchdog logrotate strace cryptsetup postfix vim app-misc/screen xz-utils hdparm diffutils gzip which
#	emerge --nospinner --quiet --color n -v -puvbk1 telnet-bsd usbutils e2fsprogs virtual/man kbd wget pax-utils virtual/pager busybox less virtual/libc virtual/os-headers patch tar make sed bzip2
#	emerge --nospinner --quiet --color n -v -vubk1 telnet-bsd usbutils e2fsprogs virtual/man kbd wget pax-utils virtual/pager busybox less virtual/libc virtual/os-headers patch tar make sed bzip2
	#emerge --nospinner --quiet --color n -v -puvbk1 xymon openrc udev-init-scripts netifrc shared-mime-info virtual/udev hwids sys-apps/shadow pambase sys-apps/kmod gpgme net-misc/curl iptables net-analyzer/munin
	#emerge --nospinner --quiet --color n -v -uvbk1 xymon openrc udev-init-scripts netifrc shared-mime-info virtual/udev hwids sys-apps/shadow pambase sys-apps/kmod gpgme net-misc/curl iptables net-analyzer/munin
	#PKGS="net-analyzer/munin"
	#result $? "test-gentoo-install-misc"

fi

start_test "pretend upgrade system"
emerge --nospinner --quiet --color n -v -bkpDNu system
emerge --nospinner --quiet --color n -v -bkDNu system
result $? "test-gentoo-upgrade-system"

start_test "pretend upgrade world"
emerge --nospinner --quiet --color n -v -bkpDNu world
emerge --nospinner --quiet --color n -v -bkDNu world
result $? "test-gentoo-upgrade-world"

if [ $SELINUX -eq 1 ];then
	start_test "Generate audit2allow"
	dmesg | audit2allow
	result $? "test-gentoo-audit2allow"
fi
exit 0

