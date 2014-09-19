#!/usr/bin/perl
#Author: Eduardo Reginato Lavratti 
#Using original code from Paul Cox
#This script reads a paparazzi log file and extracts the SHOT messages
#It outputs:
#GPX file with lat,lon,alt,photonumber,cource,pitch,roll,yaw
#TXT file with lat,lon,alt,photonumber,cource,pitch,roll,yaw

#Notes:
#mode 
#utm_east ALT_UNIT="m" UNIT="cm"
#utm_north ALT_UNIT="m" UNIT="cm"
#course ALT_UNIT="deg" UNIT="decideg"
#alt ALT_UNIT="m" UNIT="cm"
#speed ALT_UNIT="m/s" UNIT="cm/s"
#climb ALT_UNIT="m/s" UNIT="cm/s"
#week weeks
#itow ms
#utm_zone
#gps_nb_err
#0       1  2   3 4        5         6    7    8 9   10   11        12 13
#time    ID MSG M EAST     NORTH     C    ALT  S C   W    ITOW      ZO ERR
#144.225 20 GPS 3 19779772 497668512 1819 3625 9 -20 1601 303393500 31 0

#DC_SHOT
#0       1  2       3 4        5          6       7   8  9  10   11 12
#time    ID MSG     N UTM      UTM        ALT     ZO  ph th COUR SP ITOW
#285.134 23 DC_SHOT 1 79712048 -246348528 714.737 22 -5 103 1437 33 70562250


use lib 'lib', '../lib', 'sw/logalizer/lib';

#libs used for graphic mode
use Tk 8.0;
use File::Basename;

use Image::EXIF;
use Data::Dumper;

use Geo::Coordinates::UTM;
require "distance.pl";

my $utw=0;
my $cnt=0;
my $toffset=0;
my $solstart=0;
my $totime=0;
my $tdtime=0;
my $hialt=0;
my $maxdist=0;
my $latitude=0;
my $longitude=0;
my $altitude=0;
my $gndalt=0;
my $delta=0;
my $pitch=0;
my $roll=0;
my $course=0;
my $picnumber=0;
my $startpic=0;

sub getnmeatime {
    my $utw_h = 0;
    my $utw_d = 0;
    my $foo = $utw/60000/60; #60*60*24*7 // 1000milisec * 60sec * 60 min * 24 hour * 7 days
    #calculate days and hours
    while ($foo > 1) {
      if ($utw_h == 23) {$utw_h = 0;$utw_d++;} else {$utw_h = $utw_h + 1;}
      $foo = $foo - 1;
    }
    #ensure proper leading zero for single digits
    $utw_h = sprintf("%02d",$utw_h);
    #foo+1 is the fractional hours
    my $utw_m = int($foo*60);
    #ensure proper leading zero for single digits
    #$utw_m = sprintf("%02d",$utw_m);
    #calculate remaining seconds
    #my $utw_s = sprintf("%02.0f",$utw/1000-$utw_m*60-$utw_h*60*60-$utw_d*60*60*24);
    my $utw_s = $utw/1000-$utw_m*60-$utw_h*60*60-$utw_d*60*60*24;
    if (int($utw_s) == 60) {
       printf "time error verify ";
       printf "time: %02f ",$utw_s;
       $utw_s = 0; 
       $utw_m = $utw_m + 1;
       #printf ( $utw_s);
       };
    #ensure proper leading zero for single digits
    $utw_m = sprintf("%02d",$utw_m);
    $utw_s = sprintf("%02d",$utw_s);
    my $time = "$utw_h:$utw_m:$utw_s"; #Time UTC HHMMSS.mmm  303318000/60000=5055.3/60=84.255/24=3.510625
    return $time;
} 


my $mw = MainWindow->new( -title => 'LOG2GPX file converter tool' );  
my $fname = $mw->getOpenFile( -title => 'Open JPEG file',-initialdir => '../../../../' );
#my $filename = '12_08_17__12_15_31';
#my $filename = $ARGV[0];


my ($filename, $path, $suffix) = fileparse($fname, '\.[^\.]*');

#my $filename = basename($path);
#my $dirname = dirname ($path);
printf "\ndiretorio: $path\n";
printf "nome arquivo: $filename\n";
printf "extension: $suffix\n\n";


   my $exif = new Image::EXIF($fname);
print "file: $fname " . Dumper ($exif->get_all_info($fname));