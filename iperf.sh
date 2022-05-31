#!/bin/sh

. ./common

get_machine_model

TEST_PREFIX="test-iperf"

get_interrupts dma-controller
get_interrupts eth0

do_iperf auto network

get_interrupts dma-controller
get_interrupts eth0

