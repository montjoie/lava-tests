#!/bin/sh

. ./common

export

LUKS_PASS="$1"

DROPBEAR=0

check_proc crond crond
check_proc sshd sshd
check_proc ssh ssh
#check_proc ssh dropbear
check_proc openvpn openvpn
check_proc ntpd ntpd

ps aux

start_test "Check openvpn version"
openvpn --version
result $? "cubie-openvpn-version"

start_test "Check sshd version"
sshd --version
result $? "cubie-sshd-version"

#start_test "Check dropbear version"
#dropbear -V
#RET=$?
#if [ $RET -eq 0 ];then
#	DROPBEAR=1
#fi
#result $RET "cubie-dropbear-version"

start_test "Check rsync version"
rsync --version
result $? "cubie-rsync-version"

start_test "Check CIFS"
mount.cifs --version
result $? "cubie-cifs-version"

start_test "Use smartctl"
smartctl -a /dev/sda
result $? "cubie-smart"

echo "DEBUG: test LUKS with $LUKS_PASS"

test_luks() {
start_test "Check cryptsetup version"
cryptsetup --version
result $? "cubie-cryptsetup-version"

echo "$LUKS_PASS" > $OUTPUT_DIR/fake.key
cryptsetup luksOpen --key-file="$OUTPUT_DIR/fake.key" --batch-mode /dev/sda2 backup
if [ $? -eq 0 ];then
	cryptsetup info backup

	fsck.ext4 -vf /dev/mapper/backup

	cryptsetup luksClose backup
fi
}
fdisk -l

sed -i 's,remote.*,remote 192.168.1.100,' /etc/openvpn/openvpn_cert.conf
/etc/init.d/S60openvpn restart
sleep 5

#udhcpc -i eth0 -n
ip route

ping -c1 ssh.lava.local
if [ $? -eq 0 ];then
	wget -q http://ssh.lava.local/id_rsa.lavatest
	wget -q http://ssh.lava.local/id_rsa.pub
	mkdir -p /root/.ssh/
	mv id_rsa.lavatest /root/.ssh/id_rsa
	mv id_rsa.pub /root/.ssh/
	cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
	echo "Content of /root/.ssh/authorized_keys"
	cat /root/.ssh/authorized_keys
	chmod 600 /root/.ssh/id_rsa

	SSH_OPTS=""
	if [ $DROPBEAR -eq 0 ];then
		ssh-keyscan ssh.lava.local >> "/root/.ssh/known_hosts"
		SSH_OPTS="-o 'StrictHostKeyChecking no'"
	else
		SSH_OPTS="-y "
		wget -q http://ssh.lava.local/id_dropbear
		mv id_dropbear /root/.ssh/
		#dropbearconvert openssh dropbear /root/.ssh/id_rsa /root/.ssh/id_dropbear
	fi

	start_test "Test ssh output"
	ssh $SSH_OPTS lavatest@ssh.lava.local 'uname -a'
	result $? "cubie-ssh-output"
	start_test "Test ssh incoming"
	ssh $SSH_OPTS lavatest@ssh.lava.local "ssh  -o 'StrictHostKeyChecking no' root@192.168.1.220 'uname -a'"
	result $? "cubie-ssh-incoming"

	start_test "Test scp"
	scp /root/.ssh/id_rsa.pub lavatest@ssh.lava.local:~
	result $? "cubie-scp"
fi

ls -l /var/log/

tail -n 40 /var/log/messages

cat /var/log/openvpn_cert-status.log

ip a
