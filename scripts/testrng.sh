#!/bin/sh

DRIVER=$1
OUTPUT_DIR=$2
echo "SEED" | kcapi-rng --name $DRIVER -b 64 > $OUTPUT_DIR/rng.out
echo $? > $OUTPUT_DIR/rng.ret
