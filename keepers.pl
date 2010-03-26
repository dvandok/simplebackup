#!/usr/bin/perl -w

use POSIX;

use strict;
use warnings;

# backups to keep:

# daily backups up to 7 days old
# first backup of the week not older than 30 days
# first backup of the month

my $backupdir = "/media/backup-nik/bkp/camilla";
$backupdir = "./test";

opendir(DIR,$backupdir) or die "couldn't open $backupdir";

my @dates = sort { $b cmp $a } grep {
    /^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}$/ && -d "$backupdir/$_"
} readdir(DIR); closedir DIR;

#@dates = sort { $b cmp $a } @dates;

# dirty but lexical sort will do the trick
#print sort(@dates);

# convert each date to a timestamp?

# relate the backups to most recent one.
#$time = str2time("2010-01-02");

sub date2time($) {
    my $date = shift;
    my ($y, $m, $d) = ($date =~ /([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})$/);
    print STDERR "year: $y, month: $m, day: $d\n";
    return (mktime(0, 0, 0, $d -1 , $m -1 , $y -1900 ), $y, $m, $d);
}

#print localtime($time) . "\n";

my $current_date = 0;

# seconds per week
use constant WEEKSECS => 7 * 24 * 60 * 60;
use constant MONTHSECS => 30 * 24 * 60 * 60;

my @keeplist = ();

my $time;

my $keepmonth = 0;
my ($y,$m,$d);

my $firstdate = shift @dates;
my $firsttime = (date2time $firstdate)[0]; # take the first element in the array

print STDERR $firsttime . "\n";

push @keeplist, $firstdate;

my $nextdate;

# TODO: put everything in a single loop
# first loop: everything less than a week old
while ($nextdate = shift @dates) {
    ($time, $y, $m, $d) = date2time($nextdate); # another way of taking the first element in the array

    if ($firsttime - $time <= WEEKSECS) {
	push @keeplist, $nextdate;
	next;
    } else {
	unshift @dates,$nextdate;
	last;
    }
}

print STDERR "end of first week\n";

my $month = "$y-$m";

my @week = ();

# second loop; everything less than a month old
while ($nextdate = shift @dates) {
    ($time, $y, $m, $d) = date2time($nextdate);

    if ($firsttime - $time <= MONTHSECS) {
	if ("$y-$m" ne $month) {
	    # deal with last months effects
	    for (@week) {
		print STDERR "keep $_\n";
		next if not defined $_;
		push @keeplist, $_;
	    }
	    delete @week[0..3];
	    $month = "$y-$m";
	}
	$week[($d-1)/7] = $nextdate;
	next;
    } else {
	unshift @dates,$nextdate;
	last;
    }
}
for (@week) {
    next if not defined $_;
    push @keeplist, $_;
}

print STDERR "end of first month\n";

# last loop; everything that is older than a month
while ($nextdate = shift @dates) {
    ($time, $y, $m, $d) = date2time($nextdate);
    if ("$y-$m" eq $month) {
	$keepmonth = $nextdate;
    } else {
	push @keeplist, $keepmonth if ($keepmonth);
	$keepmonth = $nextdate;
	$month = "$y-$m";
    }
} 

# push the last one
push @keeplist, $keepmonth;


$,="\n";

print sort @keeplist; print  "\n";


