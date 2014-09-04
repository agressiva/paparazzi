#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#
# $Source: /projet/ivy/cvsroot/lib/ivy-perl/example/ivyprobe.pl,v $
# $Revision: 1.12 $
#
# $Author: bustico $
# $Date: 2006/10/17 14:41:37 $
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
use Term::ReadLine;

use Carp;

my $appliname = "IVYPROBE.PL";
my $bus;
my $timestamp = 0;
my $noReadLineMode ;
my $regexpFile;
my $classes;
my @classes = ();

# for each application gives the number of running instances
my %connected_applications;

# for each couple appli:host gives the number of application running on host
my %where_applications;

&check_options;
$noReadLineMode = 1 unless -t;

if (defined $classes) {
  @classes =split(/:/, $classes);
  printf ("DBG> CLASSES = %s\n", join (" , ", @classes));
}


unless (defined  $noReadLineMode) {
  my $pid;
  pipe (PIPE_READ, PIPE_WRITE);
  select PIPE_WRITE; $| = 1;
  select STDOUT; $| = 1;

  if (($pid = fork() == 0)) {
    # code du fils qui lit dans le pipe
    close (PIPE_WRITE);
    open (STDIN, "<&PIPE_READ")  or die "Can't dup STDIN on PIPE_READ: $!";
  } else {
    close (PIPE_READ);
    my $term = Term::ReadLine->new("ivyprobe.pl");
    #$term->SetHistory ();

    while (defined ($_ = $term->readline("> "))) {
      chomp;
      print PIPE_WRITE "$_\n" ;
      #$term->addhistory($_) if /\S/;
    }
    kill (15, $pid);
    waitpid ($pid, 0);
    exit (0);
  }
}


Ivy->init (-ivyBus => (defined $bus) ? $bus : undef,
	   -appName => $appliname,
	   -loopMode => 'LOCAL',
	   -messWhenReady => "$appliname READY",
	   -filterRegexp => \@classes
	   );

my $Ivyobj = Ivy->new(-statusFunc => \&statusFunc,
		      -slowAgentFunc=> \&congestionCallback,
		      -blockOnSlowAgent => 0,
		      );

foreach my $regexp (@ARGV) {
    print "binding to $regexp\n";
    if ($regexp =~ /'(.*)'/) { $regexp = $1; }
    $Ivyobj->bindRegexp($regexp, [  \&callback] );
}


if (defined ($regexpFile)) {
  open (RF, $regexpFile) || die "could not read rexp file $regexpFile\n";
  while ($_ = <RF>) {
    last if eof (RF);
    chomp;
    next unless (length ($_) > 4);
    $Ivyobj->bindRegexp($_, [  \&callback] ) ;
#    printf ("DBG> subscribe to '$_'\n");
  }
  close (RF);
}


$Ivyobj->start;

sub cb {
    my $line = <STDIN>;
    unless (defined $line) {
      die "readline mode problem : try $0 -stdio\n";
    }
    chomp $line;
    exit if (&interpret_line ($line));
}

$Ivyobj->fileEvent(*STDIN, \&cb);
$Ivyobj->mainLoop();


sub printtime {
    return if (!$timestamp);
    my ($sec,$min,$hour) = localtime();
    printf  "[%02d:%02d:%02d] ", $hour, $min, $sec;
}

# this function has 3 additionnal parameters till Ivy Version 4.6
# and now getting the new/dying applications is straightforward.
# The first 3 parameters are kept only for upward compatibility! 
sub statusFunc ($$$$$$$)  {
    my ($ref_ready, $ref_nonReady, $ref_hashReady, $appname, $status, $host, $regexp) = @_;

    if ($status eq "new") {
	&printtime;
	print  "$appname connected from $host\n";
	$where_applications{"$appname:$host"}++;
    }
    elsif ($status eq "died") {
	&printtime;
	print  "$appname disconnected from $host\n";
	$where_applications{"$appname:$host"}--;
    }
    elsif ($status eq 'subscribing') {
	&printtime;
	print  "$appname subscribed to '$regexp'\n";
    }
    elsif ($status eq 'unsubscribing') {
	&printtime;
	print  "$appname unsubscribed to '$regexp'\n";
    }
    elsif ($status eq 'filtered') {
	&printtime;
	print  "$appname subscribed to *FILTERED* '$regexp'\n";
    }
    else {
	&printtime;
	print  "Bug: unkown status; $status in &statusFunc\n";
    }

    %connected_applications = %$ref_hashReady;
}



# return 1 if exit!
sub interpret_line {
    my ($str) = @_;
    if ($str eq "") { return 0; } ;
    if ($str =~ /^([^\.])/ or $str =~ /^\\/) {
	my $count=$Ivyobj->sendMsgs($str);
	&printtime;
	print  "-> Sent to $count peer";
	if ($count > 1) { print  "s" }
	print  "\n";
	return 0;
    }
    if ($str =~ /^\.q(uit)?\s*$/) {
	return 1;
    }
    if ($str =~ /^\.h(elp)?\s*$/) {
	&line_command_usage;
	return 0;
    }

    if ($str =~ /^\.die\s+(.*)/) {
	my @applis = split (/\s+/, $1);
	foreach my $appli (@applis) {
	    &printtime;
	    $Ivyobj->sendDieTo($appli);
	}
	return 0;
    }

    if ($str =~ /^.b(ind)?\s+(.*)$/) {
	my $regexp = $2;
	if ($regexp =~ /'(.*)'/) { $regexp = $1; }
	print  "binding $regexp\n";
	$Ivyobj->bindRegexp($regexp, [  \&callback] );
	return 0;
    }

    if ($str =~ /^.u(nbind)?\s+(.*)$/) {
	my $regexp = $2;
	if ($regexp =~ /'(.*)'/) { $regexp = $1; }
	print  "unbinding $regexp\n";
	$Ivyobj->bindRegexp($regexp);
	return 0;
    }

    if ($str =~ /^.db(ind)?\s+(.*)$/) {
	my $id = $2;
	print  "direct binding id $id\n";
	$Ivyobj->bindDirect($id, [\&directCallback] );
	return 0;
    }

    if ($str =~ /^.d(irect)?\s+(\S+)\s+(\S+)\s+(.*)$/) {
	my $appname = $2;
	my $id = $3;
	my $data = $4;
	&printtime;
	print  "send direct to $appname id=$id $data\n";
	$Ivyobj->sendDirectMsgs($appname, $id, $data);
	return 0;
    }

    if ($str =~ /^.p(ing)?\s+(\S+)\s+(\d+)\s*$/) {
	my $appname = $2;
	my $timeout = $3;
	&printtime;
	print  "ping $appname timeout=$timeout\n";
	my $res = $Ivyobj->ping($appname, $timeout);
	print  "$res\n";
	return 0;
    }

    if ($str =~ /^.who\s*$/) {
	print  "Apps:";
	foreach my $app (sort keys %connected_applications) {
	    for (my $i=0; $i<$connected_applications{$app} ; $i++) {
		print  " $app";
	    }
	}
	print  "\n";
	return 0;
    }

    if ($str =~ /^.where\s+(\S+)$/) {
	my $appli = $1;
	my $found = 0;
	foreach my $app_host (keys %where_applications) {
	    my ($app,$host) = $app_host =~ /(.+):(.*)/ ;
	    if ($app eq $appli) {
		for (my $i=0; $i<$where_applications{$app_host}; $i++) {
		    print  "Application $app on $host\n";
		    $found = 1;
		}
	    }
	}
	print  "No Application $appli\n" unless ($found);
	return 0;
    }

    print  "bad command. Type '.help' for a list of commands\n";
    return 0;
}

sub callback {
    my ($appname, @param) = @_;

    my $paramString = "";
    if (scalar @param) { $paramString = join ("' '", @param); }
    print  "$appname sent '", $paramString, "'\n";
}

sub directCallback {
    my (@param) = @_;

    my $paramString = "";
    if (scalar @param) { $paramString = join ("|", @param); }
    print  "directMessage received '", $paramString, "'\n";
}

sub congestionCallback ($$$)
{
  my ($name, $addr, $state) = @_;

  printf ("\033[1m $name [$addr] %s\033[m\n", $state ? "CONGESTION" : "OK");
}



sub check_options {
    # on traite la ligne de commande
    my ($opt_help, $opt_appliname);
    GetOptions("help"   => \$opt_help,
	       "b:s"    => \$bus,
	       "name:s" => \$opt_appliname,
	       "t"      => \$timestamp,
	       "stdio"  => \$noReadLineMode,
	       "filter:s" =>  \$classes,
	       "regexpFile:s" => \$regexpFile
	       );

    if (defined $opt_appliname and $opt_appliname =~ /\s/) {
	print  "-name value should not contains blanck\n";
	&usage;
    }
    &usage if (defined $opt_help && $opt_help);
    $appliname = $opt_appliname if (defined $opt_appliname);
}


sub usage {
    print  "ivyprobe.pl [-h] [ -b <network>:<port> ]  ['regexp']*\n";
    print  " ivyprobe.pl is a simple test application for the ivy-perl library\n";
    print  " Its is based on a similar appplication available with ivy-c\n";
    print  " It waits for messages on the bus, messages writtten on the command line\n";
    print  " or commands issued on the comnand line\n";
    print  " Help for the command line is available through the command\n";
    print  " .help or .h\n";
    print  "   -h   print this help\n";
    print  "   -b   <network>:<port>\n";
    print  "        to defined the network adress and the port number\n";
    print  "        defaulted to 127:2010\n";
    print  "   -t   print a time stamp when a message is send or received\n";
    print  "   -name <this_appli_name>\n";
    print  "   -stdio  don't use gnu readline which permits to recall/edit \n";
    print  "           entries with arrow keys\n";
    print  "           This options permits to redirect ivyprobe.pl output to file\n";
    print  "   -filter  classe1,classe2,classe3,...,classeN\n";
    print  "             filter messages so that we could send only messages\n";
    print  "             beginning by  classe1 or classe2 or classe3 or ... or classeN\n";
    print  "   -regexpFile file  bind to all regexps which are in the geregexp file\n";
    print  "   \n";
    print  "   \n";
    exit;
}


sub line_command_usage { print "tutu\n";
    print  "Commands list:\n";
    print  "	.h[elp]				- this help\n";
    print  "	.q[uit]				- terminate this application\n";
    print  "	.b[ind] regexp			- add a msg to receive\n";
    print  "	.u[nbind] regexp		- remove a msg to receive\n";
    print  "	.die appname1 appname2 ...	- send die msg to appnameN\n";
    print  "	.db[ind] id			- add a direct msg to receive\n";
    print  "	.d[irect] appname id args	- send direct msg to appname\n";
    print  "	.p[ing] appname timeout		- ping appname with a delay of timeout ms NYI\n";
    print  "	.where appname			- on which host is/are appname\n";
    print  "	.who				- who is on the bus\n";
}





__END__


=head1 NAME

ivyprobe.pl - simple application to test ivy, to test other ivy-application or the perl ivy implementation.

=head1 SYNOPSIS

B<ivyprobe.pl> [-h] [-t] [-name <the_appli_name> ] [-b <network>:<port> ]  ['regexp']*

=head1 DESCRIPTION

B<ivyprobe.pl> connects to the bus and offers a simple text interface to receive and send messages, and to subscribe to messages. It is very similar to the C and Java version named ivyprobe.

If regexps are given as parameters it subscribes to theses regexp.

To send a message, just type this message on the command line. It will be send to all applications who subscribe to this message. The number of application to which the message is sent is displayed. To send a message starting with a dot, prepend a backslash like this \.xxx 

The user can input the following commands:

=over

=item B<.h[elp]>

to get the list of available commands and short explanations

=item B<.q[uit]>

to terminate the application.

=item B<.b[ind] regexp>

to add a subscription to messages matching the regexp.

=item B<.die appname1 appname2 ...>

to send a die msg to appnameN. The distant applications will stop.

=item B<.db[ind] id>

to add a direct msg of type id to receive

=item B<.d[irect] appname id string>

to send a direct msg to appname. The message type is indicated by id

=item B<.u[nbind] regexp>

To unsubscribe to messages matching the regexp

=item B<.where appname>

To get the host on which appname is/are running

=item B<.who>

to get the list of all connected applications

=back

=head1 BUGS

It should be possible to use line editing capabilities, but does not work currently.

No other know bugs at this time. Report them to author.


=head1 SEE ALSO

Ivy(3pm), perl(1), ivy-java(3), ivyprobe(1) 

=head1 AUTHORS

Christophe Mertz <mertz@cena.fr>

=head1 COPYRIGHT

CENA (C) 2000-2002

=cut
