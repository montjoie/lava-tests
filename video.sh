#!/bin/sh

. ./common

drm_test() {
	start_test "Check DRM with modetest"
	modetest
	result $? modetest
}

# test /dev/videoX
test_dev_video() {
	echo "DEBUG: TODO $1"
	start_test "Dump an image from $1"
	ffmpeg -i $1 -f null -frames 1 $OUTPUT_DIR/video$2
	result $? "test-v4l-dump-$1"
}

#try to load all USB modules
find /lib/modules -type f |grep -E 'media|video' | sed 's,.*/,,' |
while read video_module
do
	start_test "Load module $video_module"
	modprobe "$video_module"
	result $? "video-load-$video_module"
done



DO_DRM_TEST=1

get_machine_model
start_test "Check if DRM is supported on $MACHINE_MODEL_"
for dtree in $(cat $OUTPUT_DIR/devicetree)
do
	grep $dtree video.modetest.blacklist
	if [ $? -eq 0 ];then
		echo "SKIP due to $dtree"
		DO_DRM_TEST=0
	fi
done

if [ $DO_DRM_TEST -eq 1 ];then
	drm_test
else
	result SKIP modetest
fi

start_test "List all V4L devices"
v4l2-ctl --list-devices -D -l -L
result $? "test-v4l-list"

for i in $(seq 1 20)
do
	if [ -e /dev/video$i ];then
		test_dev_video /dev/video$i $i
	fi
done
