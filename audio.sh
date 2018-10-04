#!/bin/sh

. ./common
TEST_PREFIX="audio-"

# try to load all sound modules
find /lib/modules -type f |grep kernel/sound | sed 's,.*/,,' |
while read sound_module
do
	start_test "Load $sound_module"
	modprobe $sound_module
	result $? "${TEST_PREFIX}load-$sound_module"
done

if [ ! -e /dev/snd ];then
	result SKIP "audio"
	exit 0
fi

#alsactl init
#result $? audio-alsactl-init

start_test "List all ALSA recording devices via arecord"
arecord -l
result $? audio-arecord

start_test "List all ALSA playback devices via aplay"
aplay -l
result $? audio-aplay

#atest -h
#result $? audio-atest

start_test "Check presence of the sox binary"
play --version
if [ $? -ne 0 ];then
	echo "DEBUG: Missing sox package"
	result SKIP "audio-sox"
	exit 0
fi

for audiofile in $(ls audio/*wav)
do
	start_test "Run $audiofile via sox (default)"
	play -q $audiofile
	result $? audio-sox-default-$audiofile
done

export AUDIODEV=hw:0,0
export AUDIODRIVER=alsa

for audiofile in $(ls audio/*wav)
do
	start_test "Run $audiofile via sox"
	play -q $audiofile
	result $? audio-sox-$audiofile
done
