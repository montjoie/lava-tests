#!/bin/sh

DRIVER=$1
OUTPUT_DIR=$2
echo "SEED" | kcapi-rng --name "$DRIVER" -b 64 > "$OUTPUT_DIR/rng.out"
RET=$?

test_rng_more() {
	echo "SEED" | kcapi-rng --name "$DRIVER" -b 64 > "$OUTPUT_DIR/rng.out"
	echo "SEED" | kcapi-rng --name "$DRIVER" -b 128 > "$OUTPUT_DIR/rng.out"
	echo "SEED" | kcapi-rng --name "$DRIVER" -b 256 > "$OUTPUT_DIR/rng.out"
	echo "SEED" | kcapi-rng --name "$DRIVER" -b 511 > "$OUTPUT_DIR/rng.out"
	rngtest -V
	RET=$?
	if [ $RET -ne 0 ];then
		return 0
	fi
	echo "SEED" | kcapi-rng --name "$DRIVER" -b 960000 | rngtest
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
sun8i-ss-prng)
	test_rng_more
;;
sun8i-ce-prng)
	test_rng_more
;;
*)
	echo "ERROR: unknow RNG"
;;
esac

echo $RET > "$OUTPUT_DIR/rng.ret"

rm "$OUTPUT_DIR/rng.out"
