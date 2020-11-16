#!/usr/bin/env python3

import argparse
import sys
import time
import os
import socket
import re

def clientconnect():
    if args.debug:
        print("Enable port %d" % args.port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    sock.connect((args.serveur, int(args.netport)))
    sock.send(b"HELLO %d\n" % os.cpu_count())
    time.sleep(10.00)
    while True:
        try:
            sock.send(b"PING\n")
            if args.debug:
                print("PING")
        except BrokenPipeError:
            print("SRV DISCO")
            sock.close()
            return 0
        except socket.timeout:
            print("SRV DISCO")
            sock.close()
            return 0
        time.sleep(10.00)
        try:
            buf = sock.recv(1024)
            if args.debug:
                print(buf)
        except BrokenPipeError:
            print("SRV DISCO")
            sock.close()
            return 0
        except socket.timeout:
            print("SRV DISCO")
            sock.close()
            return 0

    sock.close()
    return 0

def cambrionix_daemon():
    sm = socket.socket()
    sm.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    host = socket.gethostname()
    sm.bind(("0.0.0.0", int(args.netport)))
    sm.setblocking(0)

    sm.listen(10)

    clients = []
    cmds = {}
    ports = {}
    while True:
        time.sleep(1.00)
        if args.debug:
            print(clients)
        try:
            c, addr = sm.accept()
            c.setblocking(0)
            if args.debug:
                print('Got connection from', addr)
            cstate = {}
            cstate["socket"] = c
            clients.append(cstate)
        except socket.error:
            if args.debug:
                print("pas de nouveau client")
        nclient = len(clients)
        distcc_host = ""
        if nclient > 0:
            print(distcc_host)
            if args.debug:
                print("yia des clients: %d" % nclient)
            for client in clients:
                print("DEBUG: handle client")
                print(client)
                # gen distcc hosts
                if "CPU" in client:
                    distcc_host += "%s/%s" % (client["socket"].getpeername()[0], client["CPU"])
                print(distcc_host)
                try:
                    sc = client["socket"]
                    buf = sc.recv(1024)
                    print(buf)
                    bcmds = buf.decode('UTF-8').rstrip().split(" ")
                    print("DEBUG: command %s" % bcmds[0])
                    if bcmds[0] == "HELLO":
                        client["CPU"] = bcmds[1]
                        continue
                    if bcmds[0] == "PING":
                        sc.send(b"PONG\n")
                        continue
                    if bcmds[0] == "quit":
                        sc.send(b"BYE\n")
                        sc.close()
                        clients.remove(client)
                        continue
                    print("DEBUG: wrong command or disconnect %s" % buf)
                    sc.send(b'Wrong command\n')
                    sc.close()
                    clients.remove(client)
                except socket.error:
                    if args.debug:
                        print("Nothing new for")
        continue

    close(sm)
    sys.exit(0)

parser = argparse.ArgumentParser()
parser.add_argument("--port", "-p", type=int, help="Cambrionix port to control")
parser.add_argument("--timeout", "-t", type=int, help="timeout")
parser.add_argument("--debug", "-d", help="increase debug level", action="store_true")
parser.add_argument("--daemon", "-D", help="increase debug level", action="store_true")
parser.add_argument("--netport", help="Nerwork port", default=12346)
parser.add_argument("--counterdir", type=str, help="Where to store stats")
parser.add_argument("--statedir", type=str, help="Where to store port state", default="/var/cambrionix/")
parser.add_argument("--serveur", type=str, help="Where to store port state", default="127.0.0.1")

args = parser.parse_args()

if not os.path.exists(args.statedir):
    try:
        os.mkdir(args.statedir)
    except OSError as e:
        print(e)

timeoutmax=60
if args.timeout:
    timeoutmax = args.timeout

if args.daemon:
    cambrionix_daemon()

clientconnect()

sys.exit(0)

