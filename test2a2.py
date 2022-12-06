#!/usr/bin/env python3

import argparse
import random
import serial
import string
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--port0",type=str, help="tty name of CH348 port 0")
parser.add_argument("--port1",type=str, help="tty name of CH348 port 1")
parser.add_argument("--port2",type=str, help="tty name of CH348 port 2")

args = parser.parse_args()

BAUDS = [1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 1500000]


def test(s0, s1):
    DOCTS=0
    for baud in BAUDS:
        print("TRY %s to %s baud=%d\n" % (s0, s1, baud))
        t0 = serial.Serial(s0, baud, timeout=1, parity=serial.PARITY_EVEN, rtscts=DOCTS)
        t1 = serial.Serial(s1, baud, timeout=1, parity=serial.PARITY_EVEN, rtscts=DOCTS)

        t0.write(b"TEST\n")
        t1.write(b"PLOP\n")

        x0 = t0.read(100)
        x1 = t1.read(100)

        print(x0)
        print(x1)

test(args.port0, args.port1)

