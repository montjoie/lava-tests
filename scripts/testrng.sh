#!/bin/sh

DRIVER=$1
OUTPUT_DIR=$2
echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
echo $? > $OUTPUT_DIR/rng.ret

if [ $DRIVER = 'sun8i-ss-rng' ];then
	echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 128 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 256 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 511 > $OUTPUT_DIR/rng.out
	cat /sys/kernel/debug/clk/clk_summary
	rngtest -V
	if [ $? -ne 0 ];then
		exit 0
	fi
	#echo "SEED" | kcapi-rng --name $DRIVER -b 640000 | rngtest
fi

if [ $DRIVER = 'sun8i-ce-rng' ];then
	echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 128 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 256 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 511 > $OUTPUT_DIR/rng.out
	rngtest -V
	if [ $? -ne 0 ];then
		exit 0
	fi
#	echo "SEED" | kcapi-rng --name $DRIVER -b 6400000 | rngtest 
fi

rm $OUTPUT_DIR/rng.out
