#!/usr/bin/perl -w

use strict;
use warnings;

use POSIX;
use Getopt::Long;
use File::Copy;

# read the configuration file
my $configfile= "/etc/simplebackup.conf";

# This is probably the ugliest way to read a config file.
my %conf;
open(CONF, $configfile) or die "couldn't open $configfile";
while (<CONF>) {
  if (/\s*(\w+)=(.*)/) {
    eval "\$conf{\"$1\"} = $2";
  }
}
close(CONF);

defined $conf{"host"} or die "Missing host variable in $configfile";
defined $conf{"location"} or die "Missing location variable in $configfile";


my $dryrun = 0;
my $verbose = 0;
my $host;
my $location;

GetOptions("location|l=s" => \$location,
	   "host|h=s" => \$host,
	   "dry-run" => \$dryrun,
	   "verbose" => \$verbose) or die "Could not parse options.";

if (!defined $host) {
  $host = $conf{"host"};
}

if (!defined $location) {
  $location = $conf{"location"};
}


# backups to keep:

# daily backups up to 7 days old
# first backup of the week not older than 30 days
# first backup of the month

my $backupdir = $conf{"${location}_volume"} . "/$host";

opendir(DIR,$backupdir) or die "couldn't open $backupdir";

my @dates = sort { $b cmp $a } grep {
    /^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}$/ && -d "$backupdir/$_"
} readdir(DIR); closedir DIR;

sub date2time($) {
    my $date = shift;
    my ($y, $m, $d) = ($date =~ /([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})$/);
    print STDERR "year: $y, month: $m, day: $d\n" if $verbose;
    return (mktime(0, 0, 0, $d -1 , $m -1 , $y -1900 ), $y, $m, $d);
}


my $current_date = 0;

# seconds per week
use constant WEEKSECS => 7 * 24 * 60 * 60;
use constant MONTHSECS => 30 * 24 * 60 * 60;

my @keeplist = (); # will keep these
my @toss = (); # won't keep thise
my $time;

my $keepmonth = 0;
my ($y,$m,$d);

my $firstdate = shift @dates;
my $firsttime = (date2time $firstdate)[0]; # take the first element in the array

print STDERR $firsttime . "\n" if $verbose;

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

print STDERR "end of first week\n" if $verbose;

my $month = "$y-$m";

my @week = ();

# second loop; everything less than a month old
while ($nextdate = shift @dates) {
    ($time, $y, $m, $d) = date2time($nextdate);

    if ($firsttime - $time <= MONTHSECS) {
	if ("$y-$m" ne $month) {
	    # deal with last months effects
	    for (@week) {
		print STDERR "keep $_\n" if $verbose;
		next if not defined $_;
		push @keeplist, $_;
	    }
	    delete @week[0..3];
	    $month = "$y-$m";
	}
	if (defined $week[($d-1)/7]) { push @toss, $week[($d-1)/7]; }
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

print STDERR "end of first month\n" if $verbose;

# last loop; everything that is older than a month
while ($nextdate = shift @dates) {
    ($time, $y, $m, $d) = date2time($nextdate);
    if ("$y-$m" eq $month) {
	if ($keepmonth) { push @toss, $keepmonth; }
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

if ($verbose) {
    print "Keep these:\n";
    print sort @keeplist; print  "\n";
    print "\nToss these:\n";
    print sort @toss; print "\n";
}

# if not in dryrun mode, rename the tossers
for (@toss) {
    if (! $dryrun ) {
	move("$backupdir/$_", "$backupdir/${_}.toss");
	print "toss $backupdir/${_}.toss\n";
    } else {
	print "(would rename $backupdir/$_ to $backupdir/${_}.toss)\n";
    }
}
