#!/bin/sh

. ./common

#try to load all wifi modules
find /lib/modules -type f |grep kernel/ | grep wireless | sed 's,.*/,,' |
while read -r wifi_module
do
	start_test "Load $wifi_module"
	modprobe "$wifi_module"
	result $? "wifi-load-$wifi_module"
done


echo "check regulatory.db"
find / |grep regulatory.db

start_test "Run iwconfig"
iwconfig
result $? "wifi-iwconfig"

start_test "Run iwlist"
iwlist
result $? "wifi-iwlist"

start_test "check presence of wpa_suplicant"
find / |grep wpa
result $? "wifi-wpa"

exit 0

