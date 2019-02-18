#!/bin/sh

#CHANGEID=20317
#PATCHID=1

#BASEURL=https://download.automotivelinux.org/AGL/upload/ci/$CHANGEID/$PATCHID/master/x86-64/
export TERM=dumb

if [ -z "$1" ];then
	exit 1
fi
BASEURL=$1

wget $BASEURL || exit $?
if [ $? -ne 0 ];then
	echo "ERROR: wget from $BASEURL"
	exit 1
fi

grep -o '[a-z-]*.wgt' index.html | sort | uniq |
while read wgtfile
do
	WGTNAME=$(echo $wgtfile | sed 's,.wgt$,,')
	echo "DEBUG: fetch $wgtfile"
	wget $BASEURL/$wgtfile
	if [ $? -ne 0 ];then
		echo "ERROR: wget from $BASEURL/$wgtfile"
		continue
	fi

	echo "DEBUG: list current pkgs"
	# TODO mktemp
	LIST='list'
	afm-util list > $LIST
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util list"
		continue
	fi
	if [ ! -s "$LIST" ];then
		echo "ERROR: afm-util list"
		continue
	fi

	echo "DEBUG: check presence of $WGTNAME"
	NAMEID=$(grep id\\\":\\\"${WGTNAME}@ $LIST | cut -d\" -f4 | cut -d\\ -f1)
	if [ ! -z "$NAMEID" ];then
		echo "DEBUG: $WGTNAME already installed as $NAMEID"
		# need to kill then deinstall
		afm-util ps | grep -q $WGTNAME
		if [ $? -eq 0 ];then
			echo "DEBUG: kill $WGTNAME"
			afm-util kill $WGTNAME
			if [ $? -ne 0 ];then
				echo "ERROR: afm-util kill"
				lava-test-case afm-util-pre-kill-$WGTNAME --result fail
				continue
			else
				lava-test-case afm-util-pre-kill-$WGTNAME --result pass
			fi
		else
			echo "DEBUG: no need to kill $WGTNAME"
		fi

		echo "DEBUG: deinstall $WGTNAME"
		afm-util remove $NAMEID
		if [ $? -ne 0 ];then
			echo "ERROR: afm-util remove"
			lava-test-case afm-util-remove-$WGTNAME --result fail
			continue
		else
			lava-test-case afm-util-remove-$WGTNAME --result pass
		fi
	else
		echo "DEBUG: $WGTNAME not installed"
	fi
	grep id $LIST
	
	echo "DEBUG: install $wgtfile"
	OUT="out"
	afm-util install $wgtfile > $OUT
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util install"
		lava-test-case afm-util-install-$WGTNAME --result fail
		continue
	else
		lava-test-case afm-util-install-$WGTNAME --result pass
	fi
	# message is like \"added\":\"mediaplayer@0.1\"
	NAMEID=$(grep d\\\":\\\"${WGTNAME}@ $OUT | cut -d\" -f4 | cut -d\\ -f1)
	echo "DEBUG: got $NAMEID"
	if [ -z "$NAMEID" ];then
		echo "ERROR: Cannot get nameid"
		continue
	fi

	afm-util list > $LIST
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util list"
		continue
	fi
	if [ ! -s "$LIST" ];then
		echo "ERROR: afm-util list"
		continue
	fi
	echo "DEBUG: Verify that $WGTNAME is installed"
	grep -q $NAMEID $LIST
	if [ $? -ne 0 ];then
		echo "ERROR: $WGTNAME is not installed"
	fi

	afm-util info $NAMEID
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util info"
		lava-test-case afm-util-info-$WGTNAME --result fail
	else
		lava-test-case afm-util-info-$WGTNAME --result pass
	fi

	afm-util detail $NAMEID
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util detail"
		lava-test-case afm-util-detail-$WGTNAME --result fail
	else
		lava-test-case afm-util-detail-$WGTNAME --result pass
	fi

	echo "DEBUG: check if we see the package with systemctl (before start)"
	systemctl list-units --full
	systemctl -a |grep afm

	echo "DEBUG: start $NAMEID"
	afm-util start $NAMEID > "rid"
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util start"
		lava-test-case afm-util-start-$WGTNAME --result fail
		continue
	else
		lava-test-case afm-util-start-$WGTNAME --result pass
	fi

	echo "DEBUG: check if we see the package with systemctl (after start)"
	sleep 60
	systemctl list-units --full
	systemctl -a |grep afm

	echo "DEBUG: Get RID for $NAMEID"
	PSLIST="pslist"
	afm-util ps > $PSLIST
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util ps"
		lava-test-case afm-util-ps-$WGTNAME --result fail
		continue
	else
		cat $PSLIST
		lava-test-case afm-util-ps-$WGTNAME --result pass
	fi
	# TODO, compare RID with the list in $PSLIST"
	RID="$(cat rid)"

	echo "DEBUG: status $NAMEID ($RID)"
	afm-util status $RID
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util status"
		lava-test-case afm-util-status-$WGTNAME --result fail
		continue
	else
		lava-test-case afm-util-status-$WGTNAME --result pass
	fi

	echo "DEBUG: kill $NAMEID ($RID)"
	afm-util kill $NAMEID
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util kill"
		lava-test-case afm-util-kill-$WGTNAME --result fail
		continue
	else
		lava-test-case afm-util-kill-$WGTNAME --result pass
	fi

	echo "DEBUG: start2 $NAMEID"
	afm-util start $NAMEID
	if [ $? -ne 0 ];then
		echo "ERROR: afm-util start2"
		lava-test-case afm-util-start2-$WGTNAME --result fail
		continue
	else
		lava-test-case afm-util-start2-$WGTNAME --result pass
	fi
done
