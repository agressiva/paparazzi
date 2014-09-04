#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#
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

#TODO :
# ° version avec une interface graphique mise à jour en temps reel ?
#
# ° version multithread pour ne pas ralentir les agents que l'on observe si
#   le traitement est long : pas possible partout car sous mandriva perl est compilé
#   sans support des threads par exemple, timeline : attendre mandriva 2007 pour voir si
#   perl est compilé avec le support des threads



use strict;
use Ivy;
use Getopt::Long;
use Carp;



sub usage (;$);
sub statusFunc ($$$$$$$);
sub newMessageCb ($$);
sub writeLogs ();
sub sigHandler ();
sub sendPings ();
sub receivePongCb($$);

my $appliname = "IVYSTAT.PL";
my %options;

#  my %regexpByApp = (); # $regexpByApp{"app"} = [liste de regexp]
my %appByRegexp = (); # $appByRegexp{"regexp"} = [{app1=>1 or 0 if unsubscribe, app2=>1or0, ...],
#			\&matchProcedure]
my %compteurByApp = (); # $compteurByApp{"app from"}->{"app to"}->[nb msg, nb octets]
my %appNameByhostAndPort = ();
my %diedApp = ();
my $startTime = time();
my $stopTime;

my $totalMess = 0;
my $totalBytes = 0;
my $nbActiveAgent = 0;
my $nbDeconnecteedAgent = 0;

my %sendMessByApp;
my %sendBytesByApp;
my %receiveMessByApp;
my %receiveBytesByApp;
my %connectedAppByAppFrom;
my %connectedAppByAppTo;
my %badlyAttachedRegexp; # value = [nbNoAnchor, nbDoubleAnchor]
my %pingResponse; # value = [min, max, total, nb}


END { writeLogs ();}
$SIG{'QUIT'} = $SIG{'INT'}  = \&sigHandler;


# on traite la ligne de commande
GetOptions(\%options, "help", "bus:s", "file:s", "interval:i", "running:i", "ping:i");

usage () if (defined $options{help});
usage ("log file name is mandatory") unless defined  $options{file};

if ($options{file} eq '-') {
   open (LOG, ">&", STDOUT) ||  usage ("cannot output to stdout");
} elsif (!open (LOG, ">$options{file}")) {
  usage ("cannot create writable file $options{file}");
}

Ivy->init (-ivyBus => (defined $options{bus}) ? $options{bus} : undef,
	   -appName => $appliname,
	   -loopMode => 'LOCAL',
	   -messWhenReady => "$appliname READY"
	   );

my $Ivyobj = Ivy->new (-statusFunc => \&statusFunc);
$Ivyobj->start;

$Ivyobj->bindRegexp ('(.*)', [\&newMessageCb], 1);
$Ivyobj->repeat ($options{interval}*1000, [\&writeLogs]) if exists $options{interval};
$Ivyobj->repeat ($options{ping}*1000, [\&sendPings]) if exists $options{ping};
$Ivyobj->after ($options{running}*1000, sub {exit 0;}) if exists $options{running};
$Ivyobj->mainLoop();


#==========================================================================================
#                _              _                     ______
#               | |            | |                   |  ____|
#         ___   | |_     __ _  | |_    _   _   ___   | |__     _   _   _ __     ___
#        / __|  | __|   / _` | | __|  | | | | / __|  |  __|   | | | | | '_ \   / __|
#        \__ \  \ |_   | (_| | \ |_   | |_| | \__ \  | |      | |_| | | | | | | (__
#        |___/   \__|   \__,_|  \__|   \__,_| |___/  |_|       \__,_| |_| |_|  \___|
sub statusFunc ($$$$$$$) {
  my ($ref_ready, $ref_nonReady, $ref_hashReady, $appname, $status, $host, $regexp) = @_;
  my $fqan = sprintf "%s@%s", $appname, $host;

  if ($status eq "new") {
#    print  "$appname connected from $host\n";
    $appNameByhostAndPort{$host} = $appname;
    $nbActiveAgent ++;
    $sendMessByApp{$host} = 0;
    $sendBytesByApp{$host} = 0;
    $receiveMessByApp{$host} = 0;
    $receiveBytesByApp{$host} = 0;
    $connectedAppByAppFrom{$host} =0;
    $receiveMessByApp{$host} =0;
    $pingResponse{$host} = [1e6,0,0,0,0]; #($min, $max, $total, $received, $sent)
    delete $diedApp{$host};
    #	$regexpByApp{$host} = [];
  } elsif ($status eq "died") {
    print  "$appname disconnected from $host\n";
    $nbDeconnecteedAgent ++;
    $nbActiveAgent --;
    $diedApp{$host} = 1;
  } elsif ($status eq 'subscribing') {
    my @anchorType=('', 'NOT ANCHORED', 'DOUBLE ANCHORED');
    my $anchor=0;
    study $regexp;
    unless (exists $appByRegexp{$regexp}) {
      $appByRegexp{$regexp} = [{$host => 1},
			    #	sub {@{$_[1]} =  ${$_[0]} =~ /$regexp/i;}];
			    eval ('sub {@{$_[1]} =  ${$_[0]} =~ /$regexp/io;}')];
    } else {
      $badlyAttachedRegexp{$host} = [0,0];
      ${$appByRegexp{$regexp}->[0]}{$host} = 1;
    }

    $badlyAttachedRegexp{$host} = [0,0] unless exists  $badlyAttachedRegexp{$host};
    if (($regexp !~ m|^\^|) && ($regexp !~ m|\$$|)) {
      ($badlyAttachedRegexp{$host}->[0])++;
      $anchor=1;
    } elsif (($regexp =~ m|^\^|) && ($regexp =~ m|\$$|)) {
      ($badlyAttachedRegexp{$host}->[1])++;
      $anchor=2;
    }
    print  "$fqan subscribed to $anchorType[$anchor] '$regexp'\n";
  } elsif ($status eq 'unsubscribing') {
    print  "$fqan unsubscribed to '$regexp'\n";
    ${$appByRegexp{$regexp}->[0]}{$regexp} = 0;
  } elsif ($status eq 'filtered') {
    print  "$fqan subscribed to *FILTERED* '$regexp'\n";
  } else {
    warn  "Bug: unkown status; $status in &statusFunc\n";
  }
}


#                                   __  __                         _____   _
#                                  |  \/  |                       / ____| | |
#         _ __     ___  __      __ | \  / |   ___   ___    ___   | |      | |__
#        | '_ \   / _ \ \ \ /\ / / | |\/| |  / _ \ / __|  / __|  | |      | '_ \
#        | | | | |  __/  \ V  V /  | |  | | |  __/ \__ \  \__ \  | |____  | |_) |
#        |_| |_|  \___|   \_/\_/   |_|  |_|  \___| |___/  |___/   \_____| |_.__/
sub newMessageCb ($$) {
  my ($app, $msg) = @_;
  my ($reg, $func, $hostRef, $appTo, @match, $bytes, $incMess, $incBytes);
  my $appFrom = "$app->[1]:$app->[2]";

  return unless defined $msg;
  study ($msg);
  #print ("DBG> $app->[0] [$app->[1]:$app->[2]] has sent \"$msg\"\n");

  foreach $reg (keys %appByRegexp) {
    ($hostRef, $func) = @{$appByRegexp{$reg}};
    &$func(\$msg, \@match) ;
    if (scalar (@match)) {
      $bytes = 0;
      map (($bytes+= length ($_)) && undef, @match);
      $compteurByApp{$appFrom} = {} unless (exists $compteurByApp{$appFrom});

      foreach $appTo (keys %$hostRef) {
	next if $appFrom eq $appTo;
	unless (exists $compteurByApp{$appFrom}->{$appTo}) {
	  $compteurByApp{$appFrom}->{$appTo} = [];
	  $connectedAppByAppTo{$appTo}++;
	  $connectedAppByAppFrom{$appFrom}++;
	}
	
	$incMess = $$hostRef{$appTo};
	$incBytes = $incMess ? $bytes : 0;
	$compteurByApp{$appFrom}->{$appTo}->[1] += $incBytes;
	$compteurByApp{$appFrom}->{$appTo}->[0] += $incMess;

	$totalMess += $incMess;
	$totalBytes += $incBytes;

	$sendMessByApp{$appFrom} += $incMess;
	$sendBytesByApp{$appFrom}+= $incBytes;
	$receiveMessByApp{$appTo} += $incMess;
	$receiveBytesByApp{$appTo} += $incBytes;

	# DEBUG
#	if ($$hostRef{$appTo}) {
#	  printf "DBG> %s@%s a envoyé %s [%s] à %s@%s\n", 
#		  $appNameByhostAndPort{$appFrom}, $appFrom, $msg, $bytes,
#		  $appNameByhostAndPort{$appTo}, $appTo;
#	}
	# END DEBUG
      }
    }
  }
}


#                           _    _             _                 __ _
#                          (_)  | |           | |               / _` |
#        __      __  _ __   _   | |_     ___  | |        ___   | (_| |  ___
#        \ \ /\ / / | '__| | |  | __|   / _ \ | |       / _ \   \__, | / __|
#         \ V  V /  | |    | |  \ |_   |  __/ | |____  | (_) |   __/ | \__ \
#          \_/\_/   |_|    |_|   \__|   \___| |______|  \___/   |___/  |___/
sub writeLogs ()
{
  # général :
  #  time, nb agent, nb mess, nb octets
  # details :
  #  pour chaque agent, par ordre de nb octets envoyés  :
  #   total : nb octets envoyés, nb mess envoyés, nb octets reçus, nb mess reçus
  #   pour chaque agents en receptions :
  #	 nb octets envoyés, nb mess envoyés,
  my (@sortedApp, $appf, $appn, $appt, $regx, $numRegx);
  my %regxByNumOccur;

  # il faut que le filehandle LOG soit valide
  return unless fileno LOG;

  seek (LOG, 0, 0);
  $stopTime = time();
  my $stdout = select (LOG);
  printf "log from %s to %s (%d seconds)\n", localtime ($startTime).'',
          localtime ($stopTime).'', $stopTime-$startTime;
  print  "active:$nbActiveAgent, disconnected:$nbDeconnecteedAgent, " .
	 "messages:$totalMess, bytes:$totalBytes\n\n";

  foreach $regx (keys %appByRegexp) {
    $numRegx ++;
    $regxByNumOccur{scalar (keys %{$appByRegexp{$regx}->[0]})}++;
  }

  print "total of $numRegx regexps binded as following :\n";
  foreach (sort keys %regxByNumOccur) {
    printf "%d regexp%s  binded %d time%s\n", $regxByNumOccur{$_},
      $regxByNumOccur{$_} > 1 ? 's' : '',
	$_,
	$_ > 1 ? 's' : '';
  }
  print "\n";
  goto "EXIT_writeLogs" unless scalar (%appNameByhostAndPort);

  @sortedApp = reverse sort {
    $sendBytesByApp{$a} <=> $sendBytesByApp{$b}
  } keys (%appNameByhostAndPort);

  foreach $appf (@sortedApp) {
    $appn = $appNameByhostAndPort{$appf};
    print "----------------------------------------------\n";
    printf "%s@%s ",$appn, $appf;
    printf "has sent %d messages [%d bytes] to %d agents\n", $sendMessByApp{$appf},
      $sendBytesByApp{$appf}, $connectedAppByAppFrom{$appf}
	      if  $sendBytesByApp{$appf};
    printf "\t\t\ has received %d messages [%d bytes] from %d agents\n",
            $receiveMessByApp{$appf}, $receiveBytesByApp{$appf}, $connectedAppByAppTo{$appf}
	      if  $receiveMessByApp{$appf};
    printf "\t\t\ subscribe to %d NOT ANCHORED regexps\n", $badlyAttachedRegexp{$appf}->[0]
    if ($badlyAttachedRegexp{$appf}->[0]);
    printf "\t\t\ subscribe to %d DOUBLE ANCHORED regexps\n", $badlyAttachedRegexp{$appf}->[1]
    if ($badlyAttachedRegexp{$appf}->[1]);

    printf "\t\t\ has received %d messages [%d bytes] from %d agents\n",
            $receiveMessByApp{$appf}, $receiveBytesByApp{$appf}, $connectedAppByAppTo{$appf}
	      if  $receiveMessByApp{$appf};

    foreach $appt (keys %{$compteurByApp{$appf}}) {
       printf "\t\t\t has sent %d messages [%d bytes] to %s@%s\n",
	 $compteurByApp{$appf}->{$appt}->[0], $compteurByApp{$appf}->{$appt}->[1],
	   $appNameByhostAndPort{$appt}, $appt;
     }


    if ($pingResponse{$appf}->[3]) {
       printf "\t\t\t ping time in milliseconds (%d send, %d received): [min:%.2f avg:%.2f max:%.2f]\n", $pingResponse{$appf}->[4], $pingResponse{$appf}->[3],
	   $pingResponse{$appf}->[0], $pingResponse{$appf}->[2]/$pingResponse{$appf}->[3],
	     $pingResponse{$appf}->[1];
    } elsif ($pingResponse{$appf}->[4]) {
      print "\t\t\t does NOT respond to ping\n",
    }

    print "\n\n";
  }

 EXIT_writeLogs:
  select ($stdout);
}

#                                   _    _____    _             __ _
#                                  | |  |  __ \  (_)           / _` |
#         ___     ___   _ __     __| |  | |__) |  _    _ __   | (_| |  ___
#        / __|   / _ \ | '_ \   / _` |  |  ___/  | |  | '_ \   \__, | / __|
#        \__ \  |  __/ | | | | | (_| |  | |      | |  | | | |   __/ | \__ \
#        |___/   \___| |_| |_|  \__,_|  |_|      |_|  |_| |_|  |___/  |___/
sub sendPings ()
{
  my $appf;

  foreach $appf (keys (%appNameByhostAndPort)) {
    next if exists $diedApp{$appf};
    $pingResponse{$appf}->[4]++;
    $Ivyobj->ping ($appf, \&receivePongCb);
  }
}



sub receivePongCb($$)
{
  my ($time, $appf) = @_;
  my ($min, $max, $total, $received, $sent) = @{$pingResponse{$appf}};

  $min = $time if $time < $min;
  $max = $time if $time > $max;
  $total += $time;
  $received ++;
#  printf ("DBG> :$received: $appf [$min, $time, $max]\n");
  @{$pingResponse{$appf}} = ($min, $max, $total, $received, $sent);
}



#                _     __ _   _    _                       _    _
#               (_)   / _` | | |  | |                     | |  | |
#         ___    _   | (_| | | |__| |   __ _   _ __     __| |  | |    ___   _ __
#        / __|  | |   \__, | |  __  |  / _` | | '_ \   / _` |  | |   / _ \ | '__|
#        \__ \  | |    __/ | | |  | | | (_| | | | | | | (_| |  | |  |  __/ | |
#        |___/  |_|   |___/  |_|  |_|  \__,_| |_| |_|  \__,_|  |_|   \___| |_|
sub sigHandler ()
{
  # ça parrait servir à rien, mais en fait le fait d'appeler exit dans le handler de signaux
  # permet d'appeler le bloc END{}, alors que sinon le ctrl C non trappé arrète l'execution sans
  # appeler le bloc END{}
  exit (0);
}

sub usage (;$) {
    print  "error : $_[0]\n" if defined $_[0];
    print  "ivystat [-h] [ -b <network>:<port> ] -i [interval] -r running time -f logfile\n";
    print  "   -h   print this help\n";
    print  "   -b   <network>:<port>\n";
    print  "        to defined the network adress and the port number\n";
    print  "        defaulted to 127:2010\n";
    print  "   -i   interval\n";
    print  "        interval in seconds between regeneration of logfile\n";
    print  "   -f   logfile\n";
    print  "        mandatory filename for the log, use - to dump on stdout\n";
    print  "   -r   running time\n";
    print  "        run 'running time' second, generate log and exit\n";
    print  "   -p   interval\n";
    print  "        ping all apps every interval, and gather response time\n";
    print  "   \n";
    exit;
}
