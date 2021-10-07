#!/bin/sh

. ./common

check_config VIDEO_SAA7110
check_config VIDEO_ZORAN_DC10

ZORAN_IN="unset"
ZORAN_OUT="unset"
USB_DONGLE=""

find /dev -iname 'video[0-9]*' > /tmp/video.list
while read line
do
	TMPF='/dev/shm/out'
	echo "FOUND VIDEO $line"
	start_test "Get v4l2-ctl info from $line"
	v4l2-ctl -d $line --info > $TMPF
	result $? "v4l2-ctl-info-$line"

	cat $TMPF

	grep -qi cx231xx $TMPF
	if [ $? -eq 0 ];then
		echo "FOUND USB DONGLE $line"
		USB_DONGLE="$line"
	fi
	grep -q zoran $TMPF
	if [ $? -eq 0 ];then
		echo "FOUND ZORAN as $line"
		grep -q -i capture $TMPF
		if [ $? -eq 0 ];then
			ZORAN_IN="$line"
			echo "FOUND ZORAN capture as $line"
		fi
		grep -q -i output $TMPF
		if [ $? -eq 0 ];then
			ZORAN_OUT="$line"
			echo "FOUND ZORAN output as $line"
		fi
	fi

done < /tmp/video.list
rm /tmp/video.list

if [ "$ZORAN_IN" == 'unset' ];then
	result skip "zoran-stream"
else
	start_test "zoran stream from $ZORAN_IN"
	#try_run -t 60 v4l2-ctl -d $ZORAN_IN --stream-mmap --stream-to-hdr cap.hdr --stream-count 60
	result $? "zoran-stream"
fi

curl -s http://192.168.1.22:8088/zoran-stream.dump/upload --output cap.hdr

if [ "$ZORAN_OUT" == 'unset' ];then
	result skip "zoran-stream-out"
else
	# launch capture from USB dongle
	if [ ! -z "$USB_DONGLE" ];then
		echo "DEBUG: LAUNCH USB DONGLE CAPTURE"
		ffmpeg -hide_banner -loglevel warning -t 30 -f video4linux2 -i $USB_DONGLE out.mkv&
	fi
	start_test "stream out with $ZORAN_OUT"
	v4l2-ctl -d $ZORAN_OUT --stream-out-mmap --stream-from-hdr cap.hdr
	result $? "zoran-stream-out"
fi

ls -lah

curl -F "filename=cap.hdr" -F "data=@cap.hdr" http://192.168.1.22:8088/bin/upload.py
if [ -s out.mkv ];then
	echo "DEBUG: upload out.mkv"
	curl -F "filename=out.mkv" -F "data=@out.mkv" http://192.168.1.22:8088/bin/upload.py
fi

start_test "list zoran formats"
ffmpeg -f v4l2 -list_formats all -i $ZORAN_IN
result $? "zoran-list-formats"

start_test "Capture from zoran with ffmpeg"
ffmpeg -hide_banner -loglevel warning -t 20 -f v4l2 -video_size 640x480 -i $ZORAN_IN zoran.mkv
result $? "zoran-ffmpeg-capture"

curl -F "filename=zoran.mkv" -F "data=@zoran.mkv" http://192.168.1.22:8088/bin/upload.py

start_test "Capture from zoran MJPEG with ffmpeg"
ffmpeg -hide_banner -loglevel warning -t 20 -f v4l2 -input_format mjpeg -i $ZORAN_IN zoran-mjpeg.mpeg
result $? "zoran-ffmpeg-capture-mjpeg"

curl -F "filename=zoran-mjpeg.mpeg" -F "data=@zoran-mjpeg.mpeg" http://192.168.1.22:8088/bin/upload.py

start_test "Test compliance of zoran capture"
v4l2-compliance --color never -d $ZORAN_IN
result $? "v4l2-compliance-zoran-capture"

if [ "$ZORAN_OUT" == 'unset' ];then
	result skip "v4l2-compliance-zoran-output"
else
	start_test "Test compliance of zoran output"
	v4l2-compliance --color never -d $ZORAN_OUT
	result $? "v4l2-compliance-zoran-output"
fi
