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
use Tk::DirSelect;
use File::Basename;
use File::stat;
use Time::localtime;
use Time::Piece;
use Tk::ProgressBar; 			#The progress bar module

use Tk::HList; 				#The hierarchical list module
use Tk::LabFrame;			#The frame module



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
     $utw_h = 0;
     $utw_d = 0;
    my $foo = $utw/60000/60; #60*60*24*7 // 1000milisec * 60sec * 60 min * 24 hour * 7 days
    #calculate days and hours
    while ($foo > 1) {
      if ($utw_h == 23) {$utw_h = 0;$utw_d++;} else {$utw_h = $utw_h + 1;}
      $foo = $foo - 1;
    }
    #ensure proper leading zero for single digits
    $utw_h = sprintf("%02d",$utw_h);
    #foo+1 is the fractional hours
    $utw_m = int($foo*60);
    #ensure proper leading zero for single digits
    #$utw_m = sprintf("%02d",$utw_m);
    #calculate remaining seconds
    #my $utw_s = sprintf("%02.0f",$utw/1000-$utw_m*60-$utw_h*60*60-$utw_d*60*60*24);
    $utw_s = $utw/1000-$utw_m*60-$utw_h*60*60-$utw_d*60*60*24;
    if (int($utw_s) == 60) {
       #printf "time error verify ";
       #printf "time: %02f ",$utw_s;
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


#my $mw = MainWindow->new( -title => 'LOG2GPX file converter tool' );  
my $mw = new MainWindow;
$mw->geometry("800x600");#$mw->geometry("200x300");
$mw->title("LOG2GPX converter tool");


my $pframe = $mw->LabFrame(
		-label => "Progress",

		-height => 20,
		-width 	=> 283,
	)->place( -x => 8, -y => 385); 	
	
	
	




#A frame for the track list
my $lframe = $mw->LabFrame(
		-label => "Tracklist", 	#A frame title

		-height => 330, 	#Frame height
		-width 	=> 453, 	#Frame width

	)->place( -x => 8, -y => 28); #Location on the main window

	
#############################################################
my @headers = ( "ID", "time", "Lat", "Lon","Alt");
my $grid = $lframe->Scrolled(
        'HList',
        -head       => 1,
        -columns    => scalar @headers,
        -scrollbars => 0,
        -width      => 58,
        -height     => 10,
        -background => 'white',
    )->place(-x => 0, -y => 0);

for(0..scalar @headers - 1)
{
 $grid->header('create', $_, -text => $headers[$_], -headerbackground => 'gray',);
}



#############################################################	
	
	
	
	

my $button1 = $mw -> Button(-text => "Open LOG", -command => \&load_log_sub)-> pack();
my $button8 = $mw -> Button(-text => "Open GPX", -command => \&load_gpx_sub)-> pack();

my $button2 = $mw -> Button(-text => "Print gps points", -command => \&print_gps_points_sub)-> pack();
my $button3 = $mw -> Button(-text => "Load picture data", -command => \&read_picture_data_sub)-> pack();
my $button4 = $mw -> Button(-text => "Print picture data", -command => \&print_picture_data_sub)-> pack();

my $button5 = $mw -> Button(-text => "Generate GPX file", -command => \&generate_gpx_sub)-> pack();
my $button6 = $mw -> Button(-text => "Generate photoscan file", -command => \&generate_photoscan_txt_sub)-> pack();

my $button7 = $mw -> Button(-text => "Sync time", -command => \&sync_sub)-> pack();

my $button = $mw -> Button(-text => "Quit", -command => sub { exit })-> pack();
MainLoop;
















sub load_log_sub {
my $fname = $mw->getOpenFile( -title => 'Open LOG File:',-initialdir => '~/Pictures/figueira' );
($filename, $path, $suffix) = fileparse($fname, '\.[^\.]*');

#directory select
  #my $ds  = $mw->DirSelect();
  #my $path = $ds->Show();

#my $filename = '12_08_17__12_15_31';
#my $filename = $ARGV[0];

#my $filename = basename($path);
#my $dirname = dirname ($path);
printf "\ndiretorio: $path\n";
printf "nome arquivo: $filename\n";
printf "extension: $suffix\n\n";

my @filepts = split(/\_/,$filename);
my $date = $filepts[2] . $filepts[1] . $filepts[0];
my $date1 = 20 . $filepts[0] . "-" . $filepts[1] . "-" . $filepts[2] . "T" ;
printf "NMEA Date: $date\n";
open DATAFILE, "<$path$filename.data" or die $!;
#TODO: open .log file and create nmea waypoints from flightplan waypoints
#open OUTFILE, ">GPS_data_$date.txt" or die $!;
#open GPXFILE, ">$path$filename.gpx" or die $!;
#open TXTFILE, ">$path$filename.txt" or die $!;

#cabecalho do arquivo GPX
#cabeçalho exemplo
#<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
#<gpx xmlns="http://www.topografix.com/GPX/1/0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" creator="Geotag http://geotag.sourceforge.net" xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
#printf GPXFILE "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
#printf GPXFILE "<gpx xmlns=\"http://www.topografix.com/GPX/1/0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" version=\"1.0\" creator=\"Geotag http://geotag.sourceforge.net\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd\">\n";
#printf GPXFILE"     <trk>\n";
#printf GPXFILE"        <name>$filename</name>\n";
#printf GPXFILE"        <trkseg>\n";

#printf TXTFILE "date        , itow    , time     , lat        , lon       ,pitch,roll , ASL , AGL ,course, num\n"; 

my $sacc =0;
my $pacc =0;
my $pdop =0;
my $numSV =0;
#($year,$month,$day) = Monday_of_Week($week,"2010"); #TODO:use week and day to calculate date?
while (my $line = <DATAFILE>) {
  chomp($line); 
  my @fields = split(/ /,$line);

  #Determine when GPS fix is acquired by looking for PDOP <1000 and numSV>3
  if ($fields[2] eq "GPS_SOL" and $fields[5] < 1000 and $fields[6] > 3) {
     # printf "GPS_SOL\n";
    if ($solstart == 0 ) {
      $solstart = $fields[0];
      printf "GPS SOL start time: $solstart\n";
    }
    $pacc = $fields[3];
    $sacc = $fields[4];
    $pdop = $fields[5];
    $numSV = $fields[6];
  }
  
  
  if ($fields[2] eq "BMP_STATUS") {
    $altbaro = $fields[6];
  }
  
  if ($fields[2] eq "DC_SHOT") {
    ($latitude,$longitude)=utm_to_latlon('wgs84',($fields[7] . "V"),$fields[4]/100,$fields[5]/100);
    $picnumber=$fields[3];  #numero da foto
    @latitude[$picnumber] = $latitude;
    @longitude[$picnumber] = $longitude;

    $altitude=$fields[6];   #altitude da foto
    @altitude[$picnumber] = $altitude;
    $pitch=$fields[9]/10;   #pitch da foto
    @pitch[$picnumber] = $pitch;
    $roll=$fields[8]/10;    #roll da foto
    @roll[$picnumber] = $roll;
    $course=$fields[10]/10; #yaw da foto
    @cource[$picnumber] = $cource;
    $utw=$fields[12];       #ITOW
    @utw[$picnumber] = $utw;
    $timet= getnmeatime();  #horario da foto
    $th = scalar $utw_h;
    $tm = scalar $utw_m;
    $ts = scalar $utw_s;
    $tt = $th*3600 + $tm*60 + $ts;
   # printf "Shot no:%.3i $timet lat:%.6f lon=%.6f alt=%.d\n",$fields[3],$latitude,$longitude,$altitude;
    printf "Shot no:%.3i $timet lat:%.6f lon=%.6f alt=%.d seg=%.d\n",$fields[3],$latitude,$longitude,$altitude,$tt;


## grava no formato waypoint ##   
#   printf GPXFILE "<wpt lat=\"%.6f\" lon=\"%.6f\">\n",$latitude,$longitude;
#   printf GPXFILE "<ele>%.3i</ele>\n",$fields[6];
#   printf GPXFILE "<time>$date1$timet"."Z</time>\n";
#   printf GPXFILE "<name>%.3i</name>\n",$fields[3];
#   printf GPXFILE "<desc>%.3i</desc>\n",$fields[3];
#   printf GPXFILE "</wpt>\n";
## fim grava no formato waypoint ##      
 
## grava no formato trackpoint ##   
 #  printf GPXFILE "            <trkpt lat=\"%.6f\" lon=\"%.6f\">\n",$fields[4],$fields[5];
#   printf GPXFILE "            <trkpt lat=\"%.6f\" lon=\"%.6f\">\n",$latitude,$longitude;
#   printf GPXFILE "                <ele>%.3i</ele>\n",$altitude;
#   printf GPXFILE "                <time>$date1$timet"."Z</time>\n";
#   printf GPXFILE "                <name>%.3i</name>\n",$picnumber;
#   printf GPXFILE "                <course>%.3i</course>\n",$course;
#   printf GPXFILE "                <pitch>%.2i</pitch>\n",$pitch;
#   printf GPXFILE "                <roll>%.2i</roll>\n",$roll;
#   printf GPXFILE "                <comp>34</comp>\n";
#   printf GPXFILE "            </trkpt>\n";
## fim grava no formato trackpoint ##  

## grava arquivo para uso no photoscan ##
#   printf TXTFILE "$date1 ,$utw, $timet , %.6f\ , %.6f, %.3i, %.3i, %.3i, %.3i, %.4i, %.3i\n",$latitude,$longitude,$fields[9]/10,$fields[8]/10,$altitude,$altbaro, $fields[10]/10, $picnumber;
## fim grava arquivo para uso no photoscan ##
  }
    
  
  #We are going to look for GPS messages, in mode 3 (3D fix)
  # Skip messages that have the previous utw (duplicates)
  # Skip any messages with negative altitude (GPS not initialized yet)
  if ($fields[2] eq "GPS" and $fields[3] == "3" and $fields[11] != $utw and $fields[7] > 0 and $solstart != 0) {
        #store begin flight time
    if ($toffset == 0) { 
      $toffset = $fields[0];
      printf "GPS Start Time: $toffset\n";
    }
    #Calculate delta and store for averaging at the end
    if ($prevtime == 0) {
      $prevtime = $fields[0];
    } else {
      $delta= $fields[0]-$prevtime;
      if ($delta > 2) {printf "warning: delta %.1f at $fields[0] s.\n",$delta;}
      $prevtime = $fields[0];
      $sum += $delta;
      $cnt++;
    }
    #takeoff is considered to be > 4 m/s on hor and vert
    if ($fields[8] > 400 and $fields[9] > 400 and $totime == 0) {
      $totime = $fields[0];
      $gndalt = $fields[7];
      $olat=$latitude; $olon=$longitude;
      #create waypoint
      printf "Takeoff detected at time : $totime s\n";
      $startpic=$picnumber;
    }
    
    if ($fields[7] > $hialt and $totime != 0 ) {
      $hialt = $fields[7];
      $hialtt = $fields[0];
      #store lat/lon for waypoint creation at end of program
    }
  
    #touchdown is considered when < 1 m/s on hor and vert
    if ($fields[8] < 100 and $fields[9] < 100 and $totime != 0 and $tdtime == 0) {
      $tdtime = $fields[0];
      printf "Max Alt : %.2f meters ($hialtt sec)\n",($hialt-$gndalt)/100;
      printf "Max Dist: %.3f km ($maxdistt sec)\n",$maxdist;
      printf "Valic pictures: %.3i\n",$picnumber-$startpic;
      printf "Touchdown detected at time : $tdtime s (flight time: %.2f min)\n",($tdtime-$totime)/60;
    }
   
    $utw=$fields[11];
    #divide by 100 as gps provides utm in centimeters
    ($latitude,$longitude)=utm_to_latlon('wgs84',($fields[12] . "V"),$fields[4]/100,$fields[5]/100);
    #printf OUTFILE "Time: %.2f Alt: %.2f Lat: %.6f Lon: %.6f\n",
    #                 $fields[0] - $toffset,($fields[7]/100),$latitude,$longitude;
    
    if ($totime == 0) { next;}
#    if ($tdtime != 0) { last;}
    
    my $dist = distance($latitude, $longitude, $olat, $olon, "K");
    if ( $dist > $maxdist ) { 
      $maxdist = $dist; 
      $maxdistt = $fields[0];
    }
  }
  
}
#close TXTFILE;
close DATAFILE;
#printf GPXFILE "        </trkseg>\n";        
#printf GPXFILE "     </trk>\n";
#printf GPXFILE "</gpx>\n";
#close GPXFILE;
}







sub load_gpx_sub {
my $fname = $mw->getOpenFile( -title => 'Open GPX File:',-initialdir => '~/Pictures/figueira' );
($filename, $path, $suffix) = fileparse($fname, '\.[^\.]*');

#directory select
  #my $ds  = $mw->DirSelect();
  #my $path = $ds->Show();

#my $filename = '12_08_17__12_15_31';
#my $filename = $ARGV[0];

#my $filename = basename($path);
#my $dirname = dirname ($path);
printf "\ndiretorio: $path\n";
printf "nome arquivo: $filename\n";
printf "extension: $suffix\n\n";

my @filepts = split(/\_/,$filename);
my $date = $filepts[2] . $filepts[1] . $filepts[0];
my $date1 = 20 . $filepts[0] . "-" . $filepts[1] . "-" . $filepts[2] . "T" ;
open GPXFILE, "<$path$filename.gpx" or die $!;

close DATAFILE


}















sub generate_gpx_sub {
#my @filepts = split(/\_/,$filename);
#my $date = $filepts[2] . $filepts[1] . $filepts[0];
#my $date1 = 20 . $filepts[0] . "-" . $filepts[1] . "-" . $filepts[2] . "T" ;
#printf "NMEA Date: $date\n";
#open DATAFILE, "<$path$filename.data" or die $!;
#TODO: open .log file and create nmea waypoints from flightplan waypoints
#open OUTFILE, ">GPS_data_$date.txt" or die $!;

print "$path$filename.gpx";
open GPXFILE, ">$path$filename.gpx" or die $!;

#cabecalho do arquivo GPX
#cabeçalho exemplo
#<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
#<gpx xmlns="http://www.topografix.com/GPX/1/0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" creator="Geotag http://geotag.sourceforge.net" xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
printf GPXFILE "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
printf GPXFILE "<gpx xmlns=\"http://www.topografix.com/GPX/1/0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" version=\"1.0\" creator=\"Geotag http://geotag.sourceforge.net\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd\">\n";
printf GPXFILE"     <trk>\n";
printf GPXFILE"        <name>$filename</name>\n";
printf GPXFILE"        <trkseg>\n";

my $sacc =0;
my $pacc =0;
my $pdop =0;
my $numSV =0;
#($year,$month,$day) = Monday_of_Week($week,"2010"); #TODO:use week and day to calculate date?

printf " \n Veio do array \n";
 $size = scalar @timet;
    print "size of array: $size.\n"; 
#foreach my $timet(@timet) {
for ($picnumber=1; $picnumber < $size; $picnumber = $picnumber + 1){
    $latitude =  @latitude[$picnumber];
    $longitude = @longitude[$picnumber];
    $altitude = @altitude[$picnumber];
    $pitch = @pitch[$picnumber];
    $roll = @roll[$picnumber];
    $course = @cource[$picnumber];
    $utw = @utw[$picnumber];
    #$timet= getnmeatime();
    $timet = @timet[$picnumber];
    printf "Shot no:%.3i $timet lat:%.6f lon=%.6f alt=%.d\n",$picnumber,$latitude,$longitude,$altitude;
   
## grava no formato waypoint ##   
#   printf GPXFILE "<wpt lat=\"%.6f\" lon=\"%.6f\">\n",$latitude,$longitude;
#   printf GPXFILE "<ele>%.3i</ele>\n",$fields[6];
#   printf GPXFILE "<time>$date1$timet"."Z</time>\n";
#   printf GPXFILE "<name>%.3i</name>\n",$picnumber;
#   printf GPXFILE "<desc>%.3i</desc>\n",$picnumber;
#   printf GPXFILE "</wpt>\n";
## fim grava no formato waypoint ##      
 
## grava no formato trackpoint ##   
 #  printf GPXFILE "            <trkpt lat=\"%.6f\" lon=\"%.6f\">\n",$fields[4],$fields[5];
   printf GPXFILE "            <trkpt lat=\"%.6f\" lon=\"%.6f\">\n",$latitude,$longitude;
   printf GPXFILE "                <ele>%.3i</ele>\n",$altitude;
   printf GPXFILE "                <time>$date1$timet"."Z</time>\n";
   printf GPXFILE "                <name>%.3i</name>\n",$picnumber;
   printf GPXFILE "                <course>%.3i</course>\n",$course;
   printf GPXFILE "                <pitch>%.2i</pitch>\n",$pitch;
   printf GPXFILE "                <roll>%.2i</roll>\n",$roll;
   printf GPXFILE "                <comp>34</comp>\n";
   printf GPXFILE "            </trkpt>\n";
## fim grava no formato trackpoint ##  
  }
printf GPXFILE "        </trkseg>\n";        
printf GPXFILE "     </trk>\n";
printf GPXFILE "</gpx>\n";
close GPXFILE;
} #fim generate_gpx_sub    
    
    

    
    
    
    
    
    
    
sub generate_photoscan_txt_sub {
my @filepts = split(/\_/,$filename);
#my $date = $filepts[2] . $filepts[1] . $filepts[0];
my $date1 = 20 . $filepts[0] . "-" . $filepts[1] . "-" . $filepts[2] . "T" ;

print "$path$filename.txt";
open TXTFILE, ">$path$filename.txt" or die $!;
printf TXTFILE "date        , itow    , time     , lat        , lon       ,pitch,roll , ASL , AGL ,course, num\n"; 

my $sacc =0;
my $pacc =0;
my $pdop =0;
my $numSV =0;
#($year,$month,$day) = Monday_of_Week($week,"2010"); #TODO:use week and day to calculate date?

printf " \n Veio do array \n";
 $size = scalar @timet;
    print "size of array: $size.\n"; 
#foreach my $timet(@timet) {
for ($picnumber=1; $picnumber < $size; $picnumber = $picnumber + 1){
    $latitude =  @latitude[$picnumber];
    $longitude = @longitude[$picnumber];
    $altitude = @altitude[$picnumber];
    $pitch = @pitch[$picnumber];
    $roll = @roll[$picnumber];
    $course = @cource[$picnumber];
    $utw = @utw[$picnumber];
    #$timet= getnmeatime();
    $timet = @timet[$picnumber];
    printf "Shot no:%.3i $timet lat:%.6f lon=%.6f alt=%.d\n",$picnumber,$latitude,$longitude,$altitude;
   
## grava arquivo para uso no photoscan ##
   printf TXTFILE "$date1 ,$utw, $timet , %.6f\ , %.6f, %.3i, %.3i, %.3i, %.3i, %.4i, %.3i\n",$latitude,$longitude,$fields[9]/10,$fields[8]/10,$altitude,$altbaro, $fields[10]/10, $picnumber;
## fim grava arquivo para uso no photoscan ##
  }
    
close TXTFILE;
} #fim generate_photoscan_txt_sub        
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
sub sync_sub {  
print "\nSincroniza fotos com gps time\n";
my $fotonum = scalar @filename;
my $gpsnum = scalar @utw;
print "numero fotos: $fotonum.\n"; 
print "numero waypoints: $gpsnum.\n";
#para cada foto
for ($f=0; $f < $fotonum; $f = $f + 1){
     my @fields = split(/ /,@lt[$f]);
     $ft = $fields[3];
     
     my @tim = split(/:/,$ft);
     my $th = scalar $tim[0];
     my $tm = scalar $tim[1];
     my $ts = scalar $tim[2];
     $tt1 = $th*3600 + $tm*60 + $ts;
   #  print $f, " ", @filename[$f], "  time:", $ft;
   #  print "   $tim[0],$tim[1],$tim[2] - $tt1 \n ";
     for ($g=0; $g < $gpsnum; $g = $g + 1){
	#print @timet[$g],"\n";
	    $utw = @utw[$g];
	    $uuu = scalar $utw;
	   # print "$utw \n";
	    $timet = getnmeatime();  #horario da foto
	    my $th = scalar $utw_h;
	    my $tm = scalar $utw_m;
	    my $ts = scalar $utw_s;
	    $tt2 = $th*3600 + $tm*60 + $ts;
	    $tt3 = $tt1 + 1;
	    $tt4 = $tt1 - 1;
	   # print "$tt4 < $tt1 > $tt3 -- $tt2";
	    if (($tt2 >= $tt4) && ($tt2 <= $tt3)) {
	    print"match $mnum ";# $f with $g \n";
	    print"$ft  $timet\n";
	    $mnum = $mnum + 1;
	    }	 
	    
    }
    #print "\n";
}
	

}#fim sync_sub
























sub print_gps_points_sub {

#funciona
printf " \n Veio do array \n";
 $size = scalar @timet;
    print "size of array: $size.\n"; 
#foreach my $timet(@timet) {
for ($n=0; $n < $size; $n = $n + 1){
#$timet= getnmeatime();
	print $n, " ", @timet[$n], " ", @longitude[$n], " ", @latitude[$n], " ", @altitude[$n], "\n";
   }
}
   

   
   
   
   
   
   
   
   
   sub read_picture_data_sub {
my $fname = $mw->getOpenFile( -title => 'Open LOG File:',-initialdir => '~/Pictures/figueira' );
my ($filename, $path, $suffix) = fileparse($fname, '\.[^\.]*');

#directory select
 # my $ds  = $mw->DirSelect();
 # my $path = $ds->Show();

#my $filename = '12_08_17__12_15_31';
#my $filename = $ARGV[0];

#my $filename = basename($path);
#my $dirname = dirname ($path);
printf "\ndiretorio: $path\n";
printf "nome arquivo: $filename\n";
printf "extension: $suffix\n\n";

opendir(DIR, $path) ;
@arr = readdir(DIR);
closedir(DIR);
$index = 1;
foreach(@arr) {
$f = $_;
@filename[$index]=$f;
$f1= $path.$f;
  $file = $f1;
 $sb = stat($file);
 $lt = localtime $sb->mtime;
#$lt = $sb->mtime; #time in seconds since the epoch
 @lt[$index] = $lt;
 my @fields = split(/ /,$lt);
 $ft = $fields[3];
 my @tim = split(/:/,$ft);
 my $th = scalar $tim[0];
 my $tm = scalar $tim[1];
 my $ts = scalar $tim[2];
 $tt1 = $th*3600 + $tm*60 + $ts;
 print $f, " ", @filename[$f], "  time:", $ft;
 print "   $tim[0],$tim[1],$tim[2] - $tt1 \n ";
 
 
 #print "filename: $f MTIME: " . localtime $sb->mtime;
 #print "filename: $f MTIME: " . $lt;
 #print "\n";
 
# my($se,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime $sb->mtime;
#        print $file, " ", $loc, "\n";

#if ($f = "..") {
#print $f, "     ",$hour," ",$min," ", $se," ",$mday," ",$mon," ",$year;
#  print "\n";
#}
$index = $index + 1;
}
print " $index file loaded \n";
}#fim read picture data



sub print_picture_data_sub {
print "\nPrint dados das fotos\n";
my $size = scalar @filename;
print "size of array: $size.\n"; 
for ($n=0; $n < $size; $n = $n + 1){
#$timet= getnmeatime();
	print $n, " ", @filename[$n], "          ", @lt[$n], "\n";
   }
} #fim print_picture_data_sub



#opendir (DIR, $path) or die $!;
  #  while (my $file = readdir(DIR)) {
   #   $sb = stat($file);
 #     print $file, "     ",$mtime,"\n";
  #   printf scalar localtime $sb->mtime;
  #    print "\n";
#my($se,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($mtime);
#        print $file, " ", $loc, "\n";

#print $file, "     ",$hour," ",$min," ", $se;
#printf "\n";
 #   }


