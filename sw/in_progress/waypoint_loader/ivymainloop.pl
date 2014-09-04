#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#
# $Source: /projet/ivy/cvsroot/lib/ivy-perl/example/ivymainloop.pl,v $
# $Revision: 1.4 $
#
# $Author: mertz $
# $Date: 2004/12/18 09:03:49 $
#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU GPL General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#	      
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#	
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA,
#	or refer to http://www.gnu.org/copyleft/gpl.html
#

use strict;
use Ivy;
use Getopt::Long;
use Carp;
use Time::HiRes qw(gettimeofday);

#delay between every request asking if a distant appli is still living!   
my $delay_between_living_request;

# a hash table containing connected applis
my %connected_applications;

# when false, no request are send any more
my $running = 1;

my $opt_name;
my $opt_delay;

my $bus;

&check_options;
$delay_between_living_request = (defined $opt_delay) ? $opt_delay : 3000;
my $appliname = (defined $opt_name) ? $opt_name : "IvyTestLoop";

Ivy->init (-ivyBus => (defined $bus) ? $bus : undef,
	   -appName => $appliname,
	   -loopMode => 'LOCAL',
	   -messWhenReady => "$appliname READY",
	   );

my $IvyObj = Ivy->new(-statusFunc => \&statusFunc,
		      );



$IvyObj->start;

$IvyObj->bindRegexp(  "^$appliname are you here\?.*(\\d\\d\\.\\d+)", [ "unused", \&yes_I_am_here] );

$IvyObj->bindRegexp(  "^pause", [ "unused", \&pause] );
$IvyObj->bindRegexp("^unpause", [ "unused", \&unpause] );

Ivy->mainLoop;



# this function has 3 additionnal parameters till Ivy Version 4.6
# and now getting the new/dying applications is straightforward.
# The first 3 parameters are kept only for upward compatibility! 
sub statusFunc {
    my ($ref_ready, $ref_nonReady, $ref_hashReady, $appname, $status, $host_or_regexp) = @_;
    if ($status eq "new") {
	print "$appname connected from $host_or_regexp\n";
	$connected_applications{$appname}="";
	$IvyObj->bindRegexp("^($appname) is here.*<sent: (.*)> <replied: (.*)>", [\&reply_received]);
	&ask_periodic_status($appname);
    }
    elsif ($status eq "died") {
	print "$appname disconnected from $host_or_regexp\n";
	$IvyObj->bindRegexp("^($appname) is here.*<sent: (.*)> <replied: (.*)>"); #unbinding
	if (defined $connected_applications{$appname}) {
	    $IvyObj->afterCancel($connected_applications{$appname});
	    undef $connected_applications{$appname};
	}
    }
    elsif ($status eq 'subscribing') {
	print "$appname subscribed to '$host_or_regexp'\n";
    }
    elsif ($status eq 'unsubscribing') {
	print "$appname unsubscribed to '$host_or_regexp'\n";
    }
    else {
	print "Bug: unkown status; $status in &statusFunc\n";
    }
    
#    %connected_applications = %$ref_hashReady;
}

sub pause {
    $running = 0;
    print "appliname is now pausing\n";
}

sub unpause {
    $running = 1;
    print "appliname is now running\n";
}

sub ask_periodic_status {
    my ($distantAppli) = @_;
    my $repeat_id = $IvyObj->repeat($delay_between_living_request,
					[  sub {&ask_if_living ($distantAppli);} ,
					   ]
					);
    $connected_applications{$distantAppli} = $repeat_id;
}

sub preciseTime {
    my $preciseTime = gettimeofday();
    my ($fracSeconds) = $preciseTime =~ /(\.\d*)/ ;
    my ($ss, $mm, $hh) = (localtime)[0..2];
    return sprintf ( "%02d:%02d:%02d.%03d", $hh,$mm,$ss,$fracSeconds*1000 );
}

sub ask_if_living {
    my ($distantAppli) = @_;
    return if (!$running);
    my $reply = "$distantAppli are you here?     (at " . &preciseTime . ")";
    $IvyObj->sendMsgs($reply);
}


sub yes_I_am_here {
    my ($ivy, $appname, $seconds) = @_;
    my $reply = "$appliname is here and living   <sent: $seconds> <replied: " .  &preciseTime . ">";
#    print "$appname asked me at $seconds if I am here and I reply: '$reply'\n";
    $IvyObj->sendMsgs($reply);
}

sub reply_received {
    my ($ivy, $appli_replying, $request_time, $reply_time) = @_;
    my ($ss) = (localtime)[0];
    my $preciseTime = gettimeofday();
    my ($fracSeconds) = $preciseTime =~ /(\.\d*)/ ;

    my $delta = $ss + $fracSeconds - $request_time;
    printf ("$appli_replying is living and needs %4.3fms for reply\n", $delta);
}



sub check_options {
    # on traite la ligne de commande
    my ($opt_help, $opt_gf);
    GetOptions("help" => \$opt_help,
	       "b:s"    => \$bus,
	       "name:s" => \$opt_name,
	       "delay:i" => \$opt_delay,
	       );

    &usage if ($opt_help && $opt_help);
}


sub usage {
    print "ivymainloop.pl [-h] [-b <network>:<port>] [-name ivyname] [-delay n]\n";
    print "   ivymainloop.pl is a simple test application for the ivy-perl library\n";
    print "   It sends periodic request on the bus and replies on similar requests\n";
    print "   Both requests and replies are precisely dated to get a general idea\n";
    print "   of performances\n";
    print " options are:\n";
    print "   -b <network>:<port>  ivy bus port, defaulted to \$IVYBUS or 127:2010\n";
    print "   -name <agent_name>   name of this agent, defaulted to 'IvyTestloop'\n";
    print "   -delay ms            delay between two requests defaulted to 3000ms\n";
    print " To use it as a demo : you should start at least two instances\n";
    print "   of this script as well as one instance of ivyprobe.pl\n";
    print "   in 3 xterms and have a look on messages exchanged with ivyprobe\n";
    print "Example:\n";
    print " > ivymainloop.pl -name foo\n";
    print " > ivymainloop.pl -name bar\n";
    print " > ivyprobe.pl    # to observe all exchanged messages\n\n";
    exit;
}



__END__

