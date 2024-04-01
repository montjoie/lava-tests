#!/usr/bin/env python3

import argparse
import random
import serial
import string
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--port0",type=str, help="tty name of CH348 port #1 to test")
parser.add_argument("--port1",type=str, help="tty name of CH348 port #2 to test")
parser.add_argument("--lava", help="Send LAVA signal", action="store_true")
parser.add_argument("--zero", help="Only zeroes and show change", action="store_true")

args = parser.parse_args()

BAUDS = [1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 1500000, 921600]
BAUDS = [9600, 19200, 38400, 57600, 115200, 230400, 1500000, 921600]

ret = 0
print('serial test v0')

def test(s0, s1):
    DOCTS=0
    for baud in BAUDS:
        print("TRY %s to %s baud=%d\n" % (s0, s1, baud))
        t0 = serial.Serial(s0, baud, timeout=1, parity=serial.PARITY_EVEN, rtscts=DOCTS)
        t1 = serial.Serial(s1, baud, timeout=1, parity=serial.PARITY_EVEN, rtscts=DOCTS)

        for size in [32, 64, 96, 192, 256, 1024, 2048]:
            readbuf = ''
            flen = 0
            pattern = string.printable
            rstr = ''.join(random.choice(pattern) for i in range(size))
            if args.zero:
                rstr = ""
                for i in range(size):
                    rstr += "0"
                print(f"DEBUG! len={len(rstr)}")
            t0.write(rstr.encode('UTF8'))
            t1.write(b"PLOP\n")

            timeout = 0
            while flen < size and timeout < 10:
                x0 = t0.read(4096)
                x1 = t1.read(4096)

                try:
                    d = x1.decode("UTF8")
                    rsize = len(d)
                except UnicodeDecodeError:
                    print("ERROR: UNICODE ERROR")
                    d = x1.decode("UTF8", errors="ignore")
                    rsize = len(d)
                    print("STRING USED:")
                    print(rstr)
                    print("STRING RECV:")
                    print(d)
                print(f"\tRECV {rsize}")
                readbuf += d
                flen += rsize
                timeout += 1
            #print(f"SENT: {rstr}")
            #print(f"RECV: {readbuf}")
            print(f"DEBUG: sent {size}, recv {flen} timeout={timeout} baud={baud}")
            if flen != size:
                print("ERROR: sizes are different")
                if args.lava:
                    print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%d-%d RESULT=fail>" % (baud, size))
                sys.exit(1)
                continue
            if readbuf != rstr:
                i = 0
                ndiff = 0
                first = True
                while i < size:
                    if readbuf[i] != rstr[i]:
                        if args.zero or first:
                            print(f"different at {i} {readbuf[i]} {rstr[i]}")
                            first = False
                        ndiff += 1
                    i += 1
                print("================================================================")
                print(f"ERROR: strings are different (ndiff={ndiff})")
                if args.lava:
                    print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%d-%d RESULT=fail>" % (baud, size))
                sys.exit(1)
                continue
            if args.lava:
                print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%d-%d RESULT=pass>" % (baud, size))

test(args.port0, args.port1)
sys.exit(ret)
