#!/bin/sh

. ./common

dmesg > $OUTPUT_DIR/dmesg.final
if [ -e $OUTPUT_DIR/dmesg.start ];then
	diff -u $OUTPUT_DIR/dmesg.start $OUTPUT_DIR/dmesg.final
else
	exit 1
fi

date +%s > $OUTPUT_DIR/timestamp.final
TSTAMP_START=$(cat $OUTPUT_DIR/timestamp.start)
TSTAMP_FINAL=$(cat $OUTPUT_DIR/timestamp.final)
TSTAMP_DIFF=$(($TSTAMP_FINAL-$TSTAMP_START))
echo "TestSuite runned for $TSTAMP_DIFF s"
