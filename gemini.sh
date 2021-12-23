#!/bin/sh

. ./common

export

LUKS_PASS="$1"

check_proc crond crond
check_proc sshd sshd
check_proc ssh ssh
check_proc openvpn openvpn
check_proc ntpd ntpd

ps aux

start_test "Check openvpn version"
openvpn --version
result $? "gemini-openvpn-version"

start_test "Check sshd version"
sshd --version
result $? "gemini-sshd-version"

start_test "Check rsync version"
rsync --version
result $? "gemini-rsync-version"

start_test "Use smartctl"
smartctl -a /dev/sda
result $? "gemini-smart"

echo "DEBUG: test LUKS with $LUKS_PASS"

start_test "Check cryptsetup version"
cryptsetup --version
result $? "gemini-cryptsetup-version"

echo "$LUKS_PASS" > $OUTPUT_DIR/fake.key
cryptsetup luksOpen --key-file="$OUTPUT_DIR/fake.key" --batch-mode /dev/sda2 backup
if [ $? -eq 0 ];then
	cryptsetup info backup

	fsck.ext4 -vf /dev/mapper/backup

	cryptsetup luksClose backup
fi

fdisk -l

udhcpc -i eth0 -n
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

	ssh-keyscan ssh.lava.local >> "/root/.ssh/known_hosts"
	start_test "Test ssh output"
	ssh -o 'StrictHostKeyChecking no' lavatest@ssh.lava.local 'uname -a'
	result $? "gemini-ssh-output"
	start_test "Test ssh incoming"
	ssh -o 'StrictHostKeyChecking no' lavatest@ssh.lava.local "ssh  -o 'StrictHostKeyChecking no' root@192.168.1.220 'uname -a'"
	result $? "gemini-ssh-incoming"

	start_test "Test scp"
	scp /root/.ssh/id_rsa.pub lavatest@ssh.lava.local:~
	result $? "gemini-scp"
fi

T_SLEEP=$(($(($(date +%M)%10))+1))
if [ $T_SLEEP -ge 1 ];then
	T_SLEEP=$(($T_SLEEP*60))
	echo "DEBUG: waiting for cron, sleeping $T_SLEEP seconds from $(date)"
	sleep ${T_SLEEP}
fi
mount

start_test "Check that cron ran bootstrap"
mount | grep -q '/dev/sda1'
result $? "gemini-mount"

ls -l /var/log/

tail -n 40 /var/log/messages

cat /var/log/openvpn_cert-status.log

ip a
