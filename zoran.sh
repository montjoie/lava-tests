#!/bin/sh

. ./common

check_config VIDEO_SAA7110
check_config VIDEO_ZORAN_DC10

ZORAN_IN="unset"
ZORAN_OUT="unset"
USB_DONGLE=""
UPLOAD_URL="http://192.168.1.22:8088/bin/upload.py"

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
	#try_run -t 65 v4l2-ctl -d $ZORAN_IN --stream-mmap --stream-to-hdr cap.hdr --stream-count 60
	result $? "zoran-stream"

	#start_test "Upload cap.hdr"
	#curl -F "filename=cap.hdr" -F "data=@cap.hdr" $UPLOAD_URL
	#result $? "zoran-upload-caphdr"

fi

mount -t debugfs none /sys/kernel/debug/

start_test "Grab cap.hdr"
curl -s http://192.168.1.22:8088/cap.hdr --output cap.hdr
result $? "zoran-grab-caphdr"

if [ "$ZORAN_OUT" == 'unset' ];then
	result skip "zoran-stream-out"
else
	cat /sys/kernel/debug/DC*/debug > $OUTPUT_DIR/dbg_zoran.orig
	# launch capture from USB dongle
	if [ ! -z "$USB_DONGLE" ];then
		echo "DEBUG: LAUNCH USB DONGLE CAPTURE $(date)"
		ffmpeg -hide_banner -loglevel warning -t 30 -f video4linux2 -i $USB_DONGLE out.mkv 2>$OUTPUT_DIR/ffmpeg.err >$OUTPUT_DIR/ffmpeg.out &
		sleep 2
	fi
	start_test "stream out with $ZORAN_OUT"
	v4l2-ctl -d $ZORAN_OUT --stream-out-mmap --stream-from-hdr cap.hdr
	RET=$?
	sleep 2
	result $RET "zoran-stream-out"

	echo "DEBUG: end $(date)"
	echo "DEBUG: wait for ffmpeg to end"
	TIMEOUT=0
	while [ $TIMEOUT -le 30 ]
	do
		TIMEOUT=$(($TIMEOUT+2))
		sleep 2
		ps aux |grep -v grep | grep ffmpeg
		if [ $? -ne 0 ];then
			TIMEOUT=31
		fi
		echo "WAIT $TIMEOUT"
	done
	echo "DEBUG: check remaining process XXXXXXXXXXXXXXXXXX"
	ps aux |grep ffmpeg
	echo "DEUBUG: end check XXXXXXXXXXXXXXXXXXXXXX"
	echo "DEBUG: ffmpeg out"
	cat $OUTPUT_DIR/ffmpeg.out
	echo "DEBUG: ffmpeg err"
	cat $OUTPUT_DIR/ffmpeg.err

	start_test "Dump zoran debugfs"
	cat /sys/kernel/debug/DC*/debug
	result $? "zoran-dump-debugfs"
	cat /sys/kernel/debug/DC*/debug > $OUTPUT_DIR/dbg_zoran
	diff -u $OUTPUT_DIR/dbg_zoran.orig $OUTPUT_DIR/dbg_zoran

	if [ -s out.mkv ];then
		echo "DEBUG: upload out.mkv"
		start_test "Upload out.mkv"
		curl -F "filename=out.mkv" -F "data=@out.mkv" $UPLOAD_URL
		result $? "zoran-upload-outmkv"
	fi
fi

ffmpeg_out()
{
	# now try to output with ffmpeg
	if [ "$ZORAN_OUT" == 'unset' ];then
		result skip "zoran-stream-out"
		return
	fi
	SRC=$1
	FOUT="$2"
	TN="$3"
	# launch capture from USB dongle
	if [ ! -z "$USB_DONGLE" ];then
		echo "DEBUG: LAUNCH USB DONGLE CAPTURE $(date)"
		ffmpeg -hide_banner -loglevel warning -t 30 -f video4linux2 -i $USB_DONGLE $FOUT 2>$OUTPUT_DIR/ffmpeg.err >$OUTPUT_DIR/ffmpeg.out &
		sleep 2
	fi

	start_test "Grab $SRC"
	curl -s http://192.168.1.22:8088/$SRC --output $OUTPUT_DIR/$SRC
	result $? "zoran-grab-$TN"

	start_test "stream out with $ZORAN_OUT"
	try_run -t 120 ffmpeg -i $OUTPUT_DIR/$SRC -vcodec mjpeg -an -f v4l2 $ZORAN_OUT
	RET=$?
	result $RET "zoran-ffmpeg-out-$TN"
	killall ffmpeg
	ps aux |sed 's,[[:space:]][[:space:]]*, ,g' | grep ffmpeg |grep -v grep | cut -d' ' -f2 |
	while read pid
	do
		echo "DEBUG: kill ffmpeg $pid"
		kill $pid
	done

	echo "DEBUG: end $(date)"
	echo "DEBUG: wait for ffmpeg to end"
	TIMEOUT=0
	while [ $TIMEOUT -le 30 ]
	do
		TIMEOUT=$(($TIMEOUT+2))
		sleep 2
		ps aux |grep -v grep | grep ffmpeg
		if [ $? -ne 0 ];then
			TIMEOUT=31
		fi
		echo "WAIT $TIMEOUT"
	done
	echo "DEBUG: check remaining process XXXXXXXXXXXXXXXXXX"
	ps aux |grep ffmpeg
	echo "DEUBUG: end check XXXXXXXXXXXXXXXXXXXXXX"
	echo "DEBUG: ffmpeg out"
	cat $OUTPUT_DIR/ffmpeg.out
	echo "DEBUG: ffmpeg err"
	cat $OUTPUT_DIR/ffmpeg.err

	mount -t debugfs none /sys/kernel/debug/

	start_test "Dump zoran debugfs"
	cat /sys/kernel/debug/DC*/debug
	result $? "zoran-dump-debugfs"

	if [ -s "$FOUT" ];then
		echo "DEBUG: upload $FOUT"
		start_test "Upload $FOUT"
		curl -F "filename=$FOUT" -F "data=@$FOUT" $UPLOAD_URL
		result $? "zoran-upload-$FOUT"
	fi
}

ffmpeg_out kk.avi outkk.avi kkavi
ffmpeg_out kk.avi outkk2.avi kkavi2

ls -lah

exit 0

start_test "list zoran formats"
ffmpeg -f v4l2 -list_formats all -i $ZORAN_IN
result $? "zoran-list-formats"

start_test "Capture from zoran with ffmpeg"
ffmpeg -hide_banner -loglevel warning -t 5 -f v4l2 -video_size 640x480 -i $ZORAN_IN -vcodec copy zoran.mkv
result $? "zoran-ffmpeg-capture"

curl -F "filename=zoran.mkv" -F "data=@zoran.mkv" $UPLOAD_URL
rm zoran.mkv

start_test "Capture from zoran MJPEG with ffmpeg"
ffmpeg -hide_banner -loglevel warning -t 5 -f v4l2 -input_format mjpeg -i $ZORAN_IN -vcodec copy zoran-mjpeg.mkv
result $? "zoran-ffmpeg-capture-mjpeg"

curl -F "filename=zoran-mjpeg.mkv" -F "data=@zoran-mjpeg.mkv" $UPLOAD_URL
rm zoran-mjpeg.mkv

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

start_test "Set stream to MJPG 768x576"
v4l2-ctl -d $ZORAN_IN -v pixelformat=MJPG,width=768,height=576
result $? "v4l2-stream-set-mjpg-768x576"
start_test "Stream to MJPG 768x576"
v4l2-ctl -d $ZORAN_IN --stream-mmap --stream-count 10
result $? "v4l2-stream-mjpg-768x576"

start_test "Set stream to MJPG 768x288"
v4l2-ctl -d $ZORAN_IN -v pixelformat=MJPG,width=768,height=288
result $? "v4l2-stream-set-mjpg-768x288"
start_test "Stream to MJPG 768x288"
v4l2-ctl -d $ZORAN_IN --stream-mmap --stream-count 10
result $? "v4l2-stream-mjpg-768x288"
