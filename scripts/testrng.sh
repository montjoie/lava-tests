#!/bin/sh

DRIVER=$1
OUTPUT_DIR=$2
echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
RET=$?

test_rng_more() {
	echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 128 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 256 > $OUTPUT_DIR/rng.out
	echo "SEED" | kcapi-rng --name $DRIVER -b 511 > $OUTPUT_DIR/rng.out
	rngtest -V
	if [ $? -ne 0 ];then
		return 0
	fi
	if [ $DRIVER = 'sun8i-ce-rng' ];then
		return 0
	fi
	echo "SEED" | kcapi-rng --name $DRIVER -b 640000 | rngtest
}

case $DRIVER in
sun4i_ss_rng)
	test_rng_more
;;
sun8i-ss-rng)
	test_rng_more
;;
sun8i-ce-rng)
	test_rng_more
;;
esac

echo $RET > $OUTPUT_DIR/rng.ret

rm $OUTPUT_DIR/rng.out
