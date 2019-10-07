#!/bin/sh

if [ "$1" = 'daemon' ];then
	for i in $(seq 1 100)
	do
		sunxi-fel -l | tee /sunxi.log
		sleep 30
	done
else
	$0 daemon&
fi
