#!/usr/bin/perl -w

use Tk 8.0;
use strict; 

my $mw = MainWindow->new( -title => 'File Test' );
my $menu_bar = $mw->Menu;
$mw->configure( -menu => $menu_bar );

MainLoop;


  my $filename = $mw->getOpenFile( -title => 'Open File:',
    -defaultextension => '.txt', -initialdir => '.' );
  ### do something with $filename
  warn "Opened $filename\n";

sub f_save {
  my $filename = $mw->getSaveFile( -title => 'Save File:',
    -defaultextension => '.txt', -initialdir => '.' );
  ### do something with $filename
  warn "Saved $filename\n";
}

#