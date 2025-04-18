#!/bin/sh

. ./common

FTDI=""
FTDI_2=""
CH348_0=""
CH348_1=""
CH348_2=""
CH348_6=""
CH348_7=""
PL2303=""
FTDIS0=""
FTDIS1=""

echo "DEBUG: doing lsusb"
lsusb

echo "DUMP USB serial"
ls -l /dev |grep USB

find /dev -iname 'tty*USB[0-9]*' > /tmp/allserial
while read serial
do
	echo "======================================================"
	VENDORID="$(udevadm info $serial |grep ID_VENDOR_ID | cut -d= -f2)"
	echo "FOUND $serial $VENDORID"
	case $VENDORID in
	0403)
		FTDI="$serial"
		echo "INFO: Found FTDI $serial"
		udevadm info $serial |grep -i serial
		SERIALID="$(udevadm info $serial |grep ID_SERIAL_SHORT | cut -d= -f2)"
		case $SERIALID in
		FTA5GLEL)
			#PORT2
			FTDI_2="$serial"
			echo "INFO: Found FTDI $serial for port 2"
		;;
		FTB7JDCO)
			#PORT0
			FTDI="$serial"
			echo "INFO: Found FTDI $serial for port 0"
		;;
		FTBXX2VF)
			#PORT0
			FTDI="$serial"
			echo "INFO: Found FTDI $serial for port 0"
		;;
		FT9UASWO)
			echo "INFO: Found FTDI1 $serial for FTDI2FTDI test"
			FTDIS1="$serial"
		;;
		FTBHM3LP)
			echo "INFO: Found FTDI0 $serial for FTDI2FTDI test"
			FTDIS0="$serial"
		;;
		FTA09XVS)
			echo "INFO: Found FTDI2 $serial for FTDI2FTDI test"
			FTDIS2="$serial"
		;;
		*)
			echo "ERROR: unknow ID $SERIALID"
		;;
		esac
	;;
	1a86)
		udevadm info $serial | tee /tmp/udevadm
		grep -q port0 /tmp/udevadm
		if [ $? -eq 0 ];then
			CH348_0="$serial"
			echo "INFO: Found CH348 PORT 0 $serial"
		fi
		grep -q port1 /tmp/udevadm
		if [ $? -eq 0 ];then
			CH348_1="$serial"
			echo "INFO: Found CH348 PORT 1 $serial"
		fi
		grep -q port2 /tmp/udevadm
		if [ $? -eq 0 ];then
			CH348_2="$serial"
			echo "INFO: Found CH348 PORT 2 $serial"
		fi
		grep -q port6 /tmp/udevadm
		if [ $? -eq 0 ];then
			CH348_6="$serial"
			echo "INFO: Found CH348 PORT 6 $serial"
		fi
		grep -q port7 /tmp/udevadm
		if [ $? -eq 0 ];then
			CH348_7="$serial"
			echo "INFO: Found CH348 PORT 7 $serial"
		fi
		if [ "$serial" = '/dev/ttyCH9344USB0' ];then
			CH348_0="$serial"
		fi
		if [ "$serial" = '/dev/ttyCH9344USB1' ];then
			CH348_1="$serial"
		fi
	;;
	067b)
		PL2303="$serial"
		echo "INFO: Found PL2303 0 $serial"
		#udevadm info $serial
	;;
	10c4)
		echo "INFO: Found extra cp210 for FTDI2FTDI"
		CP210="$serial"
	;;
	esac
done < /tmp/allserial

chmod 755 ./test2a2.py
if [ -e /dev/ttyCH9344USB7 ];then
	echo "VENDOR DRIVER"
	ls -l /dev/ttyCH9344USB6
	ls -l /dev/ttyCH9344USB7
	./test2a2.py --port0 /dev/ttyCH9344USB6 --port1 /dev/ttyCH9344USB7
	exit 0
fi
if [ ! -z "$FTDIS0" ];then
	./test2a2.py --port0 $FTDIS2 --port1 $CH348_0 --slow --lava ftdi2_ch348_0
	./test2a2.py --port0 $CH348_0 --port1 $FTDIS2 --slow --lava ch348_0_ftdi2
	#./test2a2.py --port0 $FTDIS2 --port1 $CP210 --slow --lava ftdi_cp210
	#./test2a2.py --port0 $CP210 --port1 $FTDIS2 --slow --lava cp210_ftdi

	./test2a2.py --port0 $FTDIS0 --port1 $FTDIS1 --slow --lava ftdi0_ftdi1
	./test2a2.py --port0 $FTDIS1 --port1 $FTDIS0 --slow --lava ftdi1_ftdi0

	exit $?
fi

if [ -z "$FTDI" ];then
	echo "ERROR: MISSING FTDI"
	exit 0
fi
if [ -z "$CH348_0" ];then
	echo "ERROR: MISSING CH348 port 0"
	exit 0
fi

echo "======================================================================="
echo "======================================================================= CH348_6 ($CH348_6) to CH348_7 ($CH348_7)"
./test2a2.py --port0 $CH348_6 --port1 $CH348_7 --slow --lava slow_ch348_6_ch348_7 || exit $?
echo "======================================================================="
echo "======================================================================= FTDI ($FTDI) to CH348_0 ($CH348_0)"
./test2a2.py --port0 $FTDI --port1 $CH348_0 --slow --lava slow_ftdi_ch348_0
./test2a2.py --port0 $CH348_0 --port1 $FTDI --slow --lava slow_ch3480_ftdi
./test2a2.py --port0 $FTDI --port1 $CH348_0 --slow
#if [ $? -ne 0 ];then
#	dmesg
#	exit 1
#fi
echo "======================================================================="
echo "======================================================================= FTDI2 ($FTDI_2) to CH348_2 ($CH348_2)"
./test2a2.py --port0 $FTDI_2 --port1 $CH348_2 --slow --lava slow_ftdi_ch348_2
echo "======================================================================="
echo "======================================================================= PL2303 ($PL2303) to CH348_1 ($CH348_1)"
./test2a2.py --port0 $PL2303 --port1 $CH348_1 --slow --lava slow_pl2303_ch348_1

echo "======================================================================="
echo "======================================================================= parallel"
./test2a2.py --parallel $FTDI:$CH348_0,$PL2303:$CH348_1,$FTDI_2:$CH348_2,$CH348_6:$CH348_7 --lava parallel || exit $?

echo "======================================================================="
echo "======================================================================= ZERO MODE"
./test2a2.py --port0 $CH348_6 --port1 $CH348_7 --zero --lava zero || exit $?
echo "======================================================================= ch348 port 6 to 7"
echo "======================================================================="
./test2a2.py --port0 $CH348_6 --port1 $CH348_7 --lava test2a2_ch348_6_ch348_7 || exit $?

dmesg

echo "======================================================================= pl2303 to port 1"
echo "======================================================================="
./test2a2.py --port1 $PL2303 --port0 $CH348_1 --lava test2a2_pl2303_ch348_1 || exit $?
echo "======================================================================="
echo "======================================================================= ftdi2 to port 0"
./test2a2.py --port0 $FTDI_2 --port1 $CH348_2 --lava test2a2_ftdi2_ch348_2 || exit $?
echo "======================================================================="
echo "======================================================================= ftdi to port 0"
./test2a2.py --port0 $FTDI --port1 $CH348_0 --lava test2a2_ftdi_ch348_0 || exit $?
echo "======================================================================="
echo "======================================================================= ftdi to port 0"
./test2a2.py --port1 $FTDI --port0 $CH348_0 --lava test2a2_ch348_0_ftdi || exit $?

echo "TEST with FTDI=$FTDI PL2303=$PL2303 and CH348 port0=$CH348_0 port1=$CH348_1"


./test2a2.py --parallel $FTDI:$CH348_0,$PL2303:$CH348_1,$FTDI_2:$CH348_2,$CH348_6:$CH348_7 || exit $?
echo "======================================================================="
echo "======================================================================="
./test2a2.py --parallel $CH348_0:$FTDI,$CH348_1:$PL2303,$CH348_2:$FTDI_2,$CH348_7:$CH348_6 || exit $?

#echo "======================================================================="
#echo "======================================================================="
#if [ -x /usr/bin/cpserialtest ];then
#/usr/bin/cpserialtest $FTDI 9600&
#/usr/bin/cpserialtest $CH348_0 9600
#else
#	find /|grep serialtest
#fi
echo "======================================================================="
echo "======================================================================="

setserial -h
echo "DEBUG: getserial"
setserial -g $FTDI
setserial -g $CH348_0
echo "DEBUG: change baud for FTDI"
setserial $FTDI baud_base 115200
echo "DEBUG: change baud for CH348"
setserial $CH348_0 baud_base 115200

OPTS=""
if [ ! -z "$CH348_2" -a ! -z "$FTDI_2" ];then
	OPTS="--port2 $CH348_2 --tport2 $FTDI_2"
fi

echo "Run testserial $OPTS"
chmod +x ./testserial.py
start_test "testserial"
./testserial.py --ftdi "$FTDI" --ch348 "$CH348_0" --pl2303 "$PL2303" --port1 "$CH348_1" $OPTS
result $? "testserial"

ls /dev |grep USB

echo "DEBUG: write FTDI"
echo "test01234567890" > $FTDI
sleep 5

echo "DEBUG: write CH348"
echo "test01234567890" > $CH348_0

start_test "rmmod ch348"
rmmod ch348
result $? "serial-rmmod"
sleep 4

start_test "modprobe ch348"
modprobe ch348
result $? "serial-modprobe"

echo "DEBUG: getserial"
setserial -g $FTDI
setserial -g $CH348_0

#echo "DEBUG: read FTDI"
#try_run -t 10 cat "$FTDI"
#sleep 5

#echo "DEBUG: read CH348"
#try_run -t 10 cat "$CH348"

#sleep 10

for i in $(seq 1 100);
do
	echo "DEBUG: modprobe/rmmod loop $i"
	#./test2a2.py --port0 $CH348_0 --port1 $CH348_1&
	rmmod ch348
	modprobe ch348
done

dmesg
