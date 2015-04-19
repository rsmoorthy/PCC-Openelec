#!/bin/bash

# For ADD, This script checks 
# a) checks if there are files in /storage/.keys Else exit
# b) checks if the device is mounted, and waits for 10 secs, before timing out
# c) checks if there is a directory by name .ishamedia and files ".encpasswd" / ".encfs6.xml" within that folder
# d) checks if the media is already mounted. if yes, exit
# e) Decrypt the public key. For each of the keys, see if the encrypted password can be decrypted. If none, exit
# f) Mount the .ishamedia on IshaMedia

# For REMOVE,
# a) checks if the encfs is already mounted. if no, exit
# b) unmount the encfs

if ! [ -z "$1" ]; then
	ACTION=$1
fi

if ! [ -z "$2" ]; then
	DEVNAME="$2"
fi
	

echo "hi $DEVNAME $ACTION" >> $LOG

DEV=`basename $DEVNAME`
LOG="/tmp/elog-$DEV"

# Mountpoint for mmc will be /storage. Else it will be the Dev Root itself
#MTRT=""
#[[ $DEVNAME =~ /dev/mmcblk.* ]] && MTRT="/storage"


# check if the public keys are present
# returns 0 if keys are not found. 1 if found
public_keys_present () {
	if [ -d "/storage/.keys" ]; then
		if ls /storage/.keys/*.enc 1> /dev/null 2>&1; then
			return 1
		else
			return 0
		fi
	fi
	return 0
}

# b) checks if the device is mounted, and waits for 10 secs, before timing out
# returns 1 if mounted, 0 if not
device_mounted () {
	date >> $LOG
	LINE=`mount | grep "^$DEVNAME"`
	echo $LINE >> $LOG
	! [ -z "$LINE" ] && return 1   # Already mounted
	#udevil mount $DEVNAME

	for x in 1 2 3 4 5
	#while [ $x -le 10 ]
	do
		LINE=`mount | grep "^$DEVNAME"`
		echo "mounted: $x $LINE" >> $LOG
		! [ -z "$LINE" ] && return 1   # mounted
		sleep 0.1
                #x=$( expr $x + 1)
	done

	# Not mounted
	return 0
}

# c) checks if there is a directory by name .ishamedia and files ".encpasswd" / ".encfs6.xml" within that folder
ishamedia_exists () {
	DEVMTPT=`mount | grep "^$DEVNAME"| awk '{print $3}'`

	if [ -d "$DEVMTPT/.ishamedia" ] && [ -f "$DEVMTPT/.ishamedia/.encfs6.xml" ] && [ -f "$DEVMTPT/.ishamedia/.encpasswd" ]; then return 1; fi
	return 0
}

# d) checks if the media is already mounted. if yes, exit
# returns 1 if mounted, 0 if not
ishamedia_mounted () {
	if [ -z "$MTRT" ]; then
		MOUNTPOINT=`mount | grep "^$DEVNAME"| awk '{print $3}'`
	else
		MOUNTPOINT=$MTRT
	fi
	LINE=`mount | grep "encfs on $MOUNTPOINT/IshaMedia type fuse"`
	[ -z "$LINE" ] && return 0
	return 1
}

# e) Decrypt the public key. For each of the keys, see if the encrypted password can be decrypted. If none, exit
# returns passwd, else empty string
get_password () {

	DEVMTPT=`mount | grep "^$DEVNAME"| awk '{print $3}'`

	for encpub in /storage/.keys/*.enc ; do
		rm -f /tmp/n.pub
		openssl enc -aes-256-cbc -d -a -in $encpub -out "/tmp/n.pub" -k 2048 2>/dev/null
		if [ -s "/tmp/n.pub" ]; then
			echo $encpub >> $LOG
			cat /tmp/n.pub >> $LOG
			PASSWD=`cat "$DEVMTPT/.ishamedia/.encpasswd" | openssl rsautl -verify -pubin -inkey /tmp/n.pub 2>/dev/null`
			echo $PASSWD >> $LOG
			! [ -z "$PASSWD" ] && echo $PASSWD && return 1
		fi
		rm -f /tmp/n.pub
	done
	return 0

	#if ! [ -s "/tmp/n.pub" ]; then 
	#	rm -f /tmp/n.pub
	#	return 0
	#fi

	#PASSWD=`cat "$DEVMTPT/.ishamedia/.encpasswd" | openssl rsautl -verify -pubin -inkey /tmp/n.pub 2>/dev/null`
	#echo $PASSWD
	#return 1
}

# f) Mount the .ishamedia on IshaMedia
mount_ishamedia () {
	DEVMTPT=`mount | grep "^$DEVNAME"| awk '{print $3}'`
	MOUNTPOINT=$DEVMTPT
	! [ -z "$MTRT" ] && MOUNTPOINT=$MTRT

	echo $1 | /usr/bin/encfs -S "$DEVMTPT/.ishamedia" "$MOUNTPOINT/IshaMedia" >> $LOG 2>&1
}


# g) Unmount IshaMedia
unmount_ishamedia () {
	DEVMTPT=`mount | grep "^$DEVNAME"| awk '{print $3}'`
	MOUNTPOINT=$DEVMTPT
	! [ -z "$MTRT" ] && MOUNTPOINT=$MTRT

	mounted=`mount | grep "$MOUNTPOINT/IshaMedia"| awk '{print $3}'`

	[ -z "$mounted" ] && return 0

	umount "$MOUNTPOINT/IshaMedia"
}

#### Main
if [ $ACTION == "ADD" ] || [ $ACTION == "add" ] ; then

	echo "1" >> $LOG
	res=$(public_keys_present)
	[ $? == "0" ] && exit

	echo "2" >> $LOG
        date >> $LOG
	res=$(device_mounted)
	if [ $? == "0" ]; then 
		echo $res >> $LOG 
		date >> $LOG 
		exit
	fi

	echo "3" >> $LOG
        date >> $LOG
	res=$(ishamedia_exists)
	[ $? == "0" ] && exit

	echo "4" >> $LOG
        date >> $LOG
	res=$(ishamedia_mounted)
	[ $? == "1" ] && exit

	echo "5" >> $LOG
        date >> $LOG
	PASSWD=$(get_password)

	echo "6 $PASSWD" >> $LOG
        date >> $LOG
	[ -z "$PASSWD" ] && exit

	echo "7" >> $LOG
        date >> $LOG
	res=$(mount_ishamedia $PASSWD)

	echo "8 $res" >> $LOG
        date >> $LOG
fi

if [ $ACTION == "REMOVE" ] || [ $ACTION == "remove" ] ; then
	res=$(ishamedia_mounted)
	[ $? == "0" ] && exit

	unmount_ishamedia
fi

exit 0
