#!/bin/bash

PATH=/bin:/usr/bin:/sbin:/usr/sbin

# parse options. Parameters are:
# -h <host> backup the remote host
# -l <location> backup to volume, either 'home' or 'work'

# by default, backup the current host
host=camilla

# default target is 'home', other possibility is 'work'.
target=home

# exclude files are here
excludedir=/usr/local/share/backup

TEMP=`getopt -o h:l: -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

while true; do
    case "$1" in
	-h) host="$2"; shift 2 ;;
	-l) target="$2"; shift 2 ;;
	--) shift; break ;;
	*) echo "Internal error" ; exit 1 ;;
    esac
done

excludefile=$excludedir/$host-excludes

# kludge to manoeuvrer the host into the rsync command line
if [ "$host" = camilla ]; then
    rhost=
else
    rhost="$host:"
fi


case $target in
    home)
	targetvolume=/media/medion_big/backup
	;;
    work)
	targetvolume=/media/backup-nik/backup
	;;
    *)
	echo "Unknown target volume '$target'"
	exit 1
	;;
esac

backupdir=$targetvolume/$host/current


rsyncflags="-rlt -P -v --delete --exclude-from=$excludefile"
cd $backupdir || { echo "target volume $targetvolume not mounted" ; exit 1 ; }

rsync $rsyncflags $rhost/ $backupdir/

if [ $? -ne 0 ]; then
    echo "rsync failure? Exiting"
    exit 1
fi

# the shared system between mac and linux
#targetdir=$targetvolume/untitled/dennis/
#sourcedir=/shared/dennis/

#( cd $sourcedir || { echo 'volume untitled not mounted' ; exit 1 ; } )
#rsync $rsyncflags $sourcedir $targetdir

# time-machine style backup
today=`date '+%Y-%m-%d'`
if [ -d $targetvolume/$host/$today ]; then
    rm -rf $targetvolume/$host/$today
fi

cp -al $targetvolume/$host/current/ $targetvolume/$host/$today/

# legacy nonsense.

if [ "$host" = camilla ]; then
    volume=mac_camilla
    backupdir=$targetvolume/${volume}
    srcdir=/media/InternalHD/Users/dennis
    excludefile=${HOME}/bin/maccamilla-excludes
    rsyncflags="-rlt -P -v --delete --exclude-from=$excludefile"
    cd $srcdir || { echo 'volume InternalHD not mounted' ; exit 1 ; }

    rsync $rsyncflags $srcdir/ $backupdir/
fi
