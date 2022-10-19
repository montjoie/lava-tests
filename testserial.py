#!/usr/bin/env python3

import argparse
import random
import serial
import string
import sys
#import pytest

parser = argparse.ArgumentParser()
parser.add_argument("--ch348",type=str, help="tty name of CH348 port 0")
parser.add_argument("--port1",type=str, help="tty name of CH348 port 1")
parser.add_argument("--port2",type=str, help="tty name of CH348 port 2")
parser.add_argument("--tport2",type=str, help="tty name of test port 2")
parser.add_argument("--ftdi",type=str, help="tty name of FTDI (test port0)")
parser.add_argument("--pl2303",type=str, help="tty name of PL2303 (test port1)")

args = parser.parse_args()

# TODO 50, 75, 110, 134, 150, 200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200.
# see https://pyserial.readthedocs.io/en/latest/pyserial_api.html
#BAUDS = [50, 75, 110, 134, 150, 200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 1500000]
BAUDS = [1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 1500000, 6000000]

def bizare(nport):
    DOCTS=0
    #for baud in [9600, 115200]:
    for baud in BAUDS:
        print("TEST bizare on port %d with baud=%d" % (nport, baud))
        if nport == 0:
            testport = serial.Serial(args.ftdi, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)
            ch348 = serial.Serial(args.ch348, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)
        elif nport == 1:
            print("TESTPORT %d is %s" % (nport, args.pl2303))
            print("PORT %d is %s" % (nport, args.port1))
            testport = serial.Serial(args.pl2303, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)
            ch348 = serial.Serial(args.port1, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)
        else:
            print("TESTPORT %d is %s" % (nport, args.tport2))
            print("PORT %d is %s" % (nport, args.port2))
            testport = serial.Serial(args.tport2, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)
            ch348 = serial.Serial(args.port2, baud, timeout=1,
                parity=serial.PARITY_EVEN, rtscts=DOCTS)

        strt = "TESTFROM_TPORT%d-%d\n" % (nport, baud)
        strch = "TESTFROMCH348-p1-%d\n" % baud
        wsizet = len(strt)
        wsizech = len(strch)
        testport.write(strt.encode("UTF8"))
        ch348.write(strch.encode("UTF8"))

        x = testport.read(100)
        rsize = len(x.decode("UTF8"))
        print("READ FROM TEST PORT %d len=%d need=%d" % (nport, rsize, wsizech))
        if rsize != wsizech:
            print("========================================")
            print(x)
            print("ERROR: TEST KO")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-bizare-write-%d-%d RESULT=fail>" % (baud, nport))
        else:
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-bizare-write-%d-%d RESULT=pass>" % (baud, nport))
        x = ch348.read(100)
        try:
            rsize = len(x.decode("UTF8"))
        except UnicodeDecodeError:
            print("ERROR: got an unicode error")
            nstr = x.decode("UTF8", errors="ignore")
            rsize = len(nstr)
        print("READ FROM CH348 len=%d need=%d" % (rsize, wsizet))
        print(x)
        if rsize != wsizet:
            print("========================================")
            print("ERROR: TEST KO")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-bizare-read-%d-%d RESULT=fail>" % (baud, nport))
        else:
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-bizare-read-%d-%d RESULT=pass>" % (baud, nport))
        testport.close()
        ch348.close()

bizare(0)
bizare(1)
bizare(2)

def simple(nport):
    for baud in [9600, 115200, 1500000, 19200, 38400, 48000, 57600, 230400 ]:
        print("+++++++++++++++++++++++++++++++++++++++++++++++++")
        print("START TEST BAUD %d on PORT %d" % (baud, nport))
        if nport == 0:
            testport = serial.Serial(args.ftdi, baud, timeout=1)
            ch348 = serial.Serial(args.ch348, baud, timeout=1)
        elif nport == 1:
            print("TESTPORT %d is %s" % (nport, args.pl2303))
            print("PORT %d is %s" % (nport, args.port1))
            testport = serial.Serial(args.pl2303, baud, timeout=1)
            ch348 = serial.Serial(args.port1, baud, timeout=1)
        else:
            print("TESTPORT %d is %s" % (nport, args.tport2))
            print("PORT %d is %s" % (nport, args.port2))
            testport = serial.Serial(args.tport2, baud, timeout=1)
            ch348 = serial.Serial(args.port2, baud, timeout=1)

        strt = "TESTFROM_TPORT%d-%d\n" % (nport, baud)
        strch = "TESTFROMCH348-p1-%d\n" % baud
        wsizet = len(strt)
        wsizech = len(strch)
        testport.write(strt.encode("UTF8"))
        ch348.write(strch.encode("UTF8"))

        x = testport.read(100)
        rsize = len(x.decode("UTF8"))
        print("READ FROM TEST PORT %d len=%d need=%d" % (nport, rsize, wsizech))
        if rsize != wsizech:
            print("========================================")
            print(x)
            print("ERROR: TEST KO")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-simple-write-%d-%d RESULT=fail>" % (baud, nport))
        else:
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-simple-write-%d-%d RESULT=pass>" % (baud, nport))
        x = ch348.read(100)
        try:
            rsize = len(x.decode("UTF8"))
        except UnicodeDecodeError:
            print("ERROR: got an unicode error")
            nstr = x.decode("UTF8", errors="ignore")
            rsize = len(nstr)
        print("READ FROM CH348 len=%d need=%d" % (rsize, wsizet))
        print(x)
        if rsize != wsizet:
            print("========================================")
            print("ERROR: TEST KO")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-simple-read-%d-%d RESULT=fail>" % (baud, nport))
        else:
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-simple-read-%d-%d RESULT=pass>" % (baud, nport))
        testport.close()
        ch348.close()

#for baud in [9600, 115200, 9600, 1500000, 19200, 38400, 48000, 57600, 230400 ]:
for baud in [9600, 115200 ]:
    print("START TEST BAUD %d" % baud)
    ftdi = serial.Serial(args.ftdi, baud, timeout=1)
    ch348 = serial.Serial(args.ch348, baud, timeout=1)

    ftdi.write(b"TESTFROMFTDI%d\n" % baud)
    ch348.write(b"TESTFROMCH348%d\n" % baud)

    x = ftdi.read(20)
    print(" READ FROM FTDI")
    print(x)
    x = ch348.read(20)
    print("READ FROM CH348")
    print(x)
    ftdi.close()
    ch348.close()

for baud in [9600, 115200, 9600, 1500000, 19200, 38400, 48000, 57600, 230400 ]:
    print("+++++++++++++++++++++++++++++++++++++++++++++++++")
    print("START TEST BAUD %d on PORT 1" % baud)
    pl2303 = serial.Serial(args.pl2303, baud, timeout=1)
    ch348 = serial.Serial(args.port1, baud, timeout=1)

    str23 = "TESTFROMPL2303-%d\n" % baud
    strch = "TESTFROMCH348-p1-%d\n" % baud
    wsize23 = len(str23)
    wsizech = len(strch)
    pl2303.write(str23.encode("UTF8"))
    ch348.write(strch.encode("UTF8"))

    x = pl2303.read(100)
    rsize = len(x.decode("UTF8"))
    print("READ FROM PL2303 len=%d need=%d" % (rsize, wsizech))
    if rsize != wsizech:
        print("========================================")
        print(x)
        print("ERROR: TEST KO")
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-first-port1-write-%d RESULT=fail>" % (baud))
    else:
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-first-port1-write-%d RESULT=pass>" % (baud))
    x = ch348.read(100)
    try:
        rsize = len(x.decode("UTF8"))
    except UnicodeDecodeError:
        print("ERROR: got an unicode error")
        nstr = x.decode("UTF8", errors="ignore")
        rsize = len(nstr)
    print("READ FROM CH348 len=%d need=%d" % (rsize, wsize23))
    print(x)
    if rsize != wsize23:
        print("========================================")
        print("ERROR: TEST KO")
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-first-port1-read-%d RESULT=fail>" % (baud))
    else:
        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-first-port1-read-%d RESULT=pass>" % (baud))
    pl2303.close()
    ch348.close()

simple(0)
simple(1)
simple(2)


def fake_uboot():
    for baud in [9600, 115200, 9600, 1500000, 19200, 38400, 48000, 57600, 230400 ]:
        print("+++++++++++++++++++++++++++++++++++++++++++++++++")
        print("START TEST fake uboot with BAUD %d on PORT 1" % baud)
        pl2303 = serial.Serial(args.pl2303, baud, timeout=1)
        ch348 = serial.Serial(args.port1, baud, timeout=1)
        step = 0
        for size in [96, 64, 192, 32, 96, 64, 32, 32, 32, 64, 32, 32, 64, 32, 32, 64, 64, 64, 96, 96, 64, 32, 128, 64]:
            step += 1
            pattern = string.ascii_lowercase
            rstr = ''.join(random.choice(pattern) for i in range(size))
            print("UBOOT STEP %d size=%d" % (step, size))
            pl2303.write(rstr.encode("UTF8"))
            x = ch348.read(1024)
            rsize = len(x.decode("UTF8"))
            if rsize != size:
                print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-uboot-%d-%d RESULT=pass>" % (baud, step))
        ch348.write(b" ")
        x = pl2303.read(20)
        rsize = len(x.decode("UTF8"))
        if rsize != 1:
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-uboot-write-%d-%d RESULT=pass>" % (baud, step))

#fake_uboot()

# generate a big string which will be sent in random chunks
def ultimate_test(nport):
    pattern = string.ascii_lowercase
    RSIZE = random.randint(1000, 2000)
    rfstr = ''.join(random.choice(pattern) for i in range(RSIZE))
    WSIZE = random.randint(1000, 2000)
    wfstr = ''.join(random.choice(pattern) for i in range(WSIZE))
    print("DEBUG: generated a read string of %d bytes" % RSIZE)
    print("DEBUG: generated a write string of %d bytes" % WSIZE)
    #for baud in [9600, 115200 ]:
    for baud in BAUDS:
        print("+++++++++++++++++++++++++++++++++++++++++++++++++")
        print("START TEST ultimate with BAUD %d on PORT %d" % (baud, nport))
        if nport == 0:
            testport = serial.Serial(args.ftdi, baud, timeout=1)
            ch348 = serial.Serial(args.ch348, baud, timeout=1)
        elif nport == 1:
            print("TESTPORT %d is %s" % (nport, args.pl2303))
            print("PORT %d is %s" % (nport, args.port1))
            testport = serial.Serial(args.pl2303, baud, timeout=1)
            ch348 = serial.Serial(args.port1, baud, timeout=1)
        else:
            print("TESTPORT %d is %s" % (nport, args.tport2))
            print("PORT %d is %s" % (nport, args.port2))
            testport = serial.Serial(args.tport2, baud, timeout=1)
            ch348 = serial.Serial(args.port2, baud, timeout=1)
        rsize_sent = 0
        rread_done = 0
        rreadstr = ""

        wsize_sent = 0
        wread_done = 0
        Wreadstr = ""

        step = 0
        FAIL = 0
        while step < 500 and FAIL < 5:
            todo = random.randint(1, 128)
            if todo > RSIZE - rsize_sent:
                todo = RSIZE - rsize_sent
            if todo > 0:
                print("DEBUG: READ: rsize=%d rsize_sent=%d todo=%d" % (RSIZE, rsize_sent, todo))
                # we will send todo_rsend bytes
                rstr = rfstr[rsize_sent:rsize_sent+todo]
                testport.write(rstr.encode("UTF8"))
                rsize_sent += todo

            todo = random.randint(1, 128)
            if todo > WSIZE - wsize_sent:
                todo = WSIZE - wsize_sent
            if todo > 0:
                print("DEBUG: WRITE: wsize=%d wsize_sent=%d todo=%d" % (WSIZE, wsize_sent, todo))
                Wstr = wfstr[wsize_sent:wsize_sent+todo]
                ch348.write(Wstr.encode("UTF8"))
                wsize_sent += todo

            todo = random.randint(1, 128)
            if todo + rread_done >= rsize_sent:
                todo = rsize_sent - rread_done
            print("DEBUG: READ: rsize_sent:=%d rread_done=%d todo=%d" % (rsize_sent, rread_done, todo))
            if todo > 0:
                x = ch348.read(todo)
                xx = x.decode("UTF8")
                rreadstr += xx
                xlen = len(xx)
                if xlen != todo:
                    print("DEBUG: READ: we read a different value xlen=%d todo=%d" % (xlen, todo))
                    rread_done += xlen
                else:
                    rread_done += todo

            todo = random.randint(1, 128)
            if todo + wread_done >= wsize_sent:
                todo = wsize_sent - wread_done
            print("DEBUG: WRITE wsize_sent=%d wread_done=%d todo=%d" % (wsize_sent, wread_done, todo))
            if todo > 0:
                x = testport.read(todo)
                xx = x.decode("UTF8")
                Wreadstr += xx
                xlen = len(xx)
                if xlen == 0:
                    FAIL += 1
                if xlen != todo:
                    print("ERROR: WRITE we read a different value xlen=%d todo=%d" % (xlen, todo))
                    wread_done += xlen
                else:
                    wread_done += todo
            if rread_done == RSIZE and wread_done == WSIZE:
                step = 99999

            step += 1
        if rreadstr != rfstr:
            print("ERROR: final string is different")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-ultimage-read-%d RESULT=fail>" % (baud))
        else:
            print("DEBUG: final string is OK")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-ultimage-read-%d RESULT=pass>" % (baud))
        if Wreadstr != wfstr:
            print("ERROR: final write string is different")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-ultimage-write-%d RESULT=fail>" % (baud))
        else:
            print("DEBUG: final write string is OK")
            print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-ultimage-write-%d RESULT=pass>" % (baud))

ultimate_test(0)
ultimate_test(1)
ultimate_test(2)

sys.exit(0)

for baud in [9600, 115200,]:
    print("START RANDOM WRITE TEST BAUD %d" % baud)
    ftdi = serial.Serial(args.ftdi, baud, timeout=1)
    ch348 = serial.Serial(args.ch348, baud, timeout=1)

    tries = 0
    while tries < 10:
        size = random.randint(1, 2)
        pattern = string.ascii_lowercase
        rstr = ''.join(random.choice(pattern) for i in range(size))
        ch348.write(rstr.encode("UTF8"))
        wsize = len(rstr)
        if wsize != size:
            print("DEBUG: incoherent %d vs %d" % (wsize, size))
        x = ftdi.read(1024)
        rsize = len(x.decode("UTF8"))
        if rsize == size:
            print("READ %d OK" % size)
        else:
            print("========================================")
            print("READ %d (need %d) KO" % (rsize, size))
        tries += 1

    ftdi.close()
    ch348.close()

for baud in [9600, 115200,]:
    print("START RANDOM READ/WRITE TEST BAUD %d" % baud)
    ftdi = serial.Serial(args.ftdi, baud, timeout=1)
    ch348 = serial.Serial(args.ch348, baud, timeout=1)

    tries = 0
    while tries < 100:
        size = random.randint(1, 2)
        way = random.randint(1, 2)
        pattern = string.ascii_lowercase
        rstr = ''.join(random.choice(pattern) for i in range(size))
        action = "unset"
        if way == 1:
            action = "WRITE"
            ch348.write(rstr.encode("UTF8"))
            x = ftdi.read(1024)
        else:
            action = "READ"
            ftdi.write(rstr.encode("UTF8"))
            x = ch348.read(1024)
        try:
            rsize = len(x.decode("UTF8"))
        except UnicodeDecodeError:
            print("ERROR: UNICODE ERROR")
            nstr = x.decode("UTF8", errors="ignore")
            rsize = len(nstr)
            print("STRING USED:")
            print(rstr)
            print("STRING RECV:")
            print(nstr)
        if rsize == size:
            print("%s %d OK (STEP %d)" % (action, size, tries))
        else:
            print("========================================")
            print("%s %d (need %d) KO" % (action, rsize, size))
        tries += 1

    ftdi.close()
    ch348.close()
sys.exit(0)

# now try to flood write it
for baud in [9600, 115200,]:
    print("START WRITE FLOOD TEST BAUD %d" % baud)
    ftdi = serial.Serial(args.ftdi, baud, timeout=1)
    ch348 = serial.Serial(args.ch348, baud, timeout=1)

    size = 0
    while size < 1024:
        pat = "TESTFROMCH348%d\n" % baud
        ch348.write(pat.encode("UTF8"))
        size += len(pat)

    x = ftdi.read(2048)
    print(" READ FROM FTDI")
    print(x)
    ftdi.close()
    ch348.close()

# now try to flood read it
for baud in [9600, 115200,]:
    print("START READ FLOOD TEST BAUD %d" % baud)
    ftdi = serial.Serial(args.ftdi, baud, timeout=1)
    ch348 = serial.Serial(args.ch348, baud, timeout=1)

    size = 0
    rsize = 0
    while size < 1024 * 1000:
        pat = "TESTFROMFTDiI%d\n" % baud
        pat = "%s%s%s" % (pat, pat, pat)
        pat = "%s%s%s" % (pat, pat, pat)
        pat = "%s%s%s" % (pat, pat, pat)
        pat = "%s%s%s" % (pat, pat, pat)
        ftdi.write(pat.encode("UTF8"))
        size += len(pat)
        x = ch348.read(500)
        rsize += len(x.decode("UTF8"))
        print("SIZE %d RSIZE %d\n" % (size, rsize))

    print(" READ FROM CH348")
    x = ch348.read(2048 * 1000)
    rsize += len(x.decode("UTF8"))
    print("SENT %d GOT %d bytes" % (size, rsize))
    if rsize == size:
        print("GOOD")
    else:
        print("BAD")
    ftdi.close()
    ch348.close()
