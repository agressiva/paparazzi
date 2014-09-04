#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use Getopt::Long;
use Ivy;
use Time::HiRes;
use Tk;

sub defaultOption ($$);

my %options;
my $numberOfSentMsg = 0;
my $numberOfSentMsgWhenCongestion = 1e6;
END {Ivy::stop ();}


# cet exemple lance deux agents un qui envoie vite de gros messages, et un autre
# qui les reçoit. Lors des 10 premières receptions il attend une seconde après 
# chaque message, ensuite il depile aussi vite qu'il peut, cet exemple permet
# de tester le bon fonctionnement du mode non bloquant.



#OPTIONS
GetOptions (\%options,  "send", "receive");

unless ((exists $options{send}) || (exists $options{receive})) {
  if (fork () == 0) {
    sleep (1);
    exec (qw (./testCongestionTk.pl -send));
  } else {
    exec (qw (./testCongestionTk.pl -receive));
  }
}

defaultOption ("bus", $ENV{IVYBUS});
if (exists ($options{send})) {
  defaultOption ("ivyname", "TESTSEND");
} else {
  defaultOption ("ivyname", "TESTRECEIVE");
}

my $t0;
my $cbAppelee = 0;
# IVY

Ivy->init (-loopMode => 'TK',
           -appName =>  $options{ivyname},
           -ivyBus => $options{bus},
           -filterRegexp => [$options{ivyname}]
	  ) ;

my $bus = Ivy->new (-statusFunc => \&statusFunc,
		    -slowAgentFunc=> \&congestionFunc,
		    -blockOnSlowAgent => 0,
		    -neededApp => exists $options{send} ?
		    ["TESTRECEIVE"] : ["TESTSEND"]);

my $mw = MainWindow->new;
my $tx1 = $mw->Text;
my $tx2 = $mw->Text  (-height => 3);
$tx2->pack (-fill => 'both', -expand => 'false');
$tx1->pack (-fill => 'both', -expand => 'true');
$mw->title ($options{ivyname});

unless (exists ($options{send})) {
  $bus->bindRegexp ('TESTSEND SEND (\d+) (.*)', [\&receiveSend]);
}

if (exists ($options{send})) {
  $mw->repeat (10, [\&send]);
}

$bus->start ();

#$bus->mainLoop ();
#Tk::MainLoop ();
Ivy::mainLoop ();


# PROCEDURES


sub receiveSend ($$)
{
   my ($app, $iter) = @_;
   $tx1->insert ('end', "RECEIVE $iter\n");
   $tx1->yviewScroll (1, 'units');
   $tx1->idletasks();
   sleep (1) if ($cbAppelee++ < 10);
}


sub send ()
{
  $t0 = Time::HiRes::gettimeofday;
  #print ("DBG> send $t0\n");

  if ($numberOfSentMsg++ <  ($numberOfSentMsgWhenCongestion+100)) {
    $tx1->insert ('end', "SEND $numberOfSentMsg\n");
    $tx1->yviewScroll (1, 'units');
    $bus->sendAppNameMsgs ("SEND $numberOfSentMsg " . 'a' x 1020);
  }
}


sub defaultOption ($$)
{
  my ($option, $default) = @_;
  unless  (defined $options{$option}) {
#    warn "option $option non spécifiéee : utilision de $default\n";
    $options{$option} = $default;
  }
}


sub statusFunc ($$)
{
  my ($ready, $notReady) = @_;

  if (@{$notReady})  {
    printf "appli manquantes : %s\n", join (' ', @{$notReady});
  } else {
    printf ("Toutes applis OK !!\n");
  }
}

sub congestionFunc ($$$)
{
  my ($name, $addr, $state) = @_;

  if ($state == 1) {
    $tx2->insert ('end', sprintf ("$name [$addr] %s will stop at N=%d\n", $state ? "CONGESTION" : "OK",
	    $numberOfSentMsg+100));
    $numberOfSentMsgWhenCongestion = $numberOfSentMsg;
  } else {
    $tx2->insert ('end', sprintf ("$name [$addr] %s\n", $state ? "CONGESTION" : "OK"));
  }
  $tx2->update();
}

