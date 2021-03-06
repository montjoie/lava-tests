#!/bin/sh

. ./common

echo "== export =="
export

echo "== COLUMNS =="
echo "COLUMNS=$COLUMNS"
COLUMNS=158

echo "== Check for tput =="
tput cols
echo $?

echo "== checkwinsize =="
shopt -s checkwinsize
echo $?

echo "== stty =="
stty size

echo "0123456789012345678901234567890123456789012345678901234567890123456789012345678X"
echo $?
echo "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678X"
echo $?
echo "012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678X"
echo $?
