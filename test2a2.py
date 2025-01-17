#!/usr/bin/env python3

import argparse
import fcntl
import os
import random
import serial
import string
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("--port0",type=str, help="tty name of CH348 port #1 to test")
parser.add_argument("--port1",type=str, help="tty name of CH348 port #2 to test")
parser.add_argument("--lava", help="Send LAVA signal", type=str, default=None)
parser.add_argument("--zero", help="Only zeroes and show change", action="store_true")
parser.add_argument("--slow", help="Slow mode", action="store_true")
parser.add_argument("--parallel", help="Test all ports in parallel")

args = parser.parse_args()
if args.parallel:
    allports = args.parallel.split(',')
    if len(allports) == 0:
        print('ERROR: not enough ports to test')
        sys.exit(1)
    #allports = []

    print(sys.argv[0])

    allp = []
    #qp = subprocess.Popen('du -a /usr/', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    #allp.append(qp)
    #qp = subprocess.Popen('ls /usr/portage', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    #allp.append(qp)
    for ports in allports:
        p = ports.split(':')
        if len(p) != 2:
            sys.exit(1)
        cmd = f'{sys.argv[0]} --port0 {p[0]} --port1 {p[1]}'
        print(cmd)
        qp = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
        #flags = fcntl.fcntl(qp.stdout, fcntl.F_GETFL)
        #flags = flags | os.O_NONBLOCK
        #fcntl.fcntl(qp.stdout, fcntl.F_SETFL, flags)

        #flags = fcntl.fcntl(qp.stderr, fcntl.F_GETFL)
        #flags = flags | os.O_NONBLOCK
        #fcntl.fcntl(qp.stderr, fcntl.F_SETFL, flags)

        allp.append(qp)


    ret = 0
    print('DEBUG: start')
    while len(allp) > 0:
        for qp in allp:
            print(f"START {qp.args} ret={qp.returncode}")
            try:
                stdout, errs = qp.communicate(timeout=1)
                out = stdout.decode('utf8')
                print(out)
            except subprocess.TimeoutExpired:
                pass
            if qp.returncode is not None:
                print(f"EXIT {qp.args} ret={qp.returncode}")
                allp.remove(qp)
            continue
            #qp.stdout.flush()
            line = 'x'
            while line != '':
                line = qp.stderr.readline().decode('UTF8').rstrip()
                print(line)
            line = 'x'
            while line != '':
                line = qp.stdout.readline().decode('UTF8').rstrip()
                print(line)
            #print(qp.returncode)
            print(f"RUN {qp.args} ret={qp.returncode}")
            #time.sleep(1)
            x = qp.communicate(timeout=1)
            print(x)
            if qp.returncode is not None:
                print(f"EXIT {qp.args} ret={qp.returncode}")
                if qp.returncode != 0:
                    ret = qp.returncode
                allp.remove(qp)
    sys.exit(ret)

BAUDS = [1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 1500000, 921600]
BAUDS = [9600, 19200, 38400, 57600, 115200, 230400, 1500000, 921600]

ret = 0
print(f'serial test v0 for {args.port0} {args.port1}')

# send string s (len l) from t0 to t1
def send_recv(t0, t1, s, l):
    print(f"DEBUG: send_recv {l}")
    sent = 0
    recved = 0
    rbuf = ''
    done = False
    timeout = 0
    while not done:
        if sent < l:
            sizetosend = random.randint(1, l - sent)
            tosend = s[sent:sent + sizetosend]
            t0.write(tosend.encode('UTF8'))
            sent += sizetosend
            print(f"DEBUG: sent {sizetosend}/{l} sent={sent} remains={l-sent}")
        time.sleep(random.randint(250, 750) / 1000)
        if recved < l:
            x1 = t1.read(random.randint(1, 256))
            try:
                d = x1.decode("UTF8")
            except UnicodeDecodeError:
                print(f"ERROR: UNICODE ERROR recv={len(x1)}")
                return 1
            rsize = len(d)
            print(f"DEBUG: RECV {rsize}")
            rbuf += d
            recved += rsize
        if recved == l:
            done = True
        timeout += 1
        if timeout > 10 and recved == 0:
            done = True
        if timeout > 100:
            done = True
    if rbuf == s:
        print(f"DEBUG: string are equal")
        return 0
    else:
        print(f"DEBUG: string are different")
        return 1


def test(s0, s1):
    print(f'DEBUG: serial test {s0} {s1}')
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
            if args.slow:
                ret = send_recv(t0, t1, rstr, size)
                if ret != 0:
                    if args.lava is not None:
                        print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-slow-%s-%d-%d RESULT=fail>" % (args.lava, baud, size))
                    else:
                        print("DEBUG: no LAVA signal")
                    return 1
                if args.lava is not None:
                    print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-slow-%s-%d-%d RESULT=pass>" % (args.lava, baud, size))
                else:
                    print("DEBUG: no LAVA signal")
                continue
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
                    print(f"ERROR: UNICODE ERROR recv={len(x1)}")
                    d = x1.decode("UTF8", errors="ignore")
                    rsize = len(d)
                    print("STRING USED:")
                    print(rstr)
                    print("STRING RECV:")
                    print(d)
                # display recv only in case of error
                if rsize != size:
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
                    print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%s-%d-%d RESULT=fail>" % (args.lava, baud, size))
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
                    print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%s-%d-%d RESULT=fail>" % (args.lava, baud, size))
                sys.exit(1)
                continue
            if args.lava:
                print("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=ch348-2a2-%s-%d-%d RESULT=pass>" % (args.lava, baud, size))

ret = test(args.port0, args.port1)
sys.exit(ret)
