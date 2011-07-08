#!/bin/bash

PATH=/bin:/usr/bin:/sbin:/usr/sbin

# parse options. Parameters are:
# -h <host> backup the remote host
# -l <location> backup to volume, either 'home' or 'work'

configfile=/etc/simplebackup.conf

# read the main configuration file
if [ -r "$configfile" ] ; then
    . "$configfile"
else
    echo "config file $configfile not found." >&2
    exit 1
fi


TEMP=`getopt -o h:l: -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

while true; do
    case "$1" in
	-h) host="$2"; shift 2 ;;
	-l) location="$2"; shift 2 ;;
	--) shift; break ;;
	*) echo "Internal error" ; exit 1 ;;
    esac
done

excludefile="$excludedir/$host-excludes"

if [ ! -r "$excludefile" ]; then
    echo "Exclude file $excludefile not found" >&2
    exit 1
fi

if [ -z "$host" ]; then
    echo "Host not set. Set host in $configfile or use -h" >&2
    exit 1
fi

if [ -z "$location" ]; then
    echo "Location not set. Set location in $configfile or use -l" >&2
    exit 1
fi

eval rhost="\$${host}_rhost"

if [ -z "$rhost" ]; then
    echo "Variable ${host}_rhost is missing or empty in $configfile" >&2
    exit 1
fi

eval targetvolume="\$${location}_volume"

if [ -z "$targetvolume" ]; then
    echo "Variable ${location}_volume is missing or empty in $configfile" >&2
    exit 1
fi


backupdir=$targetvolume/$host/current


rsyncflags="-rlt -P -v --delete --exclude-from=$excludefile"
cd $backupdir || { echo "target directory $targetvolume not present or mounted" ; exit 1 ; }

rsync $rsyncflags $rhost $backupdir/

if [ $? -ne 0 ]; then
    echo "rsync failure? Exiting (Backup not complete!)"
    exit 1
fi

# time-machine style backup
today=`date '+%Y-%m-%d'`

# This is necessary if the backup is re-done the same day. If this scares you,
# don't worry as the 'current' directory should still have the actual files.
if [ -d $targetvolume/$host/$today ]; then
    rm -rf $targetvolume/$host/$today
fi

# This makes a hardlink copy of every file to the dated directory
cp -al $targetvolume/$host/current/ $targetvolume/$host/$today/

