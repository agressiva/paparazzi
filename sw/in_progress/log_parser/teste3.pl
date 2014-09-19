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
use Time::Local;

use Image::ExifTool qw(:Public);
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
#my $latitude=0;
#my $longitude=0;
#my $altitude=0;
my $gndalt=0;
my $delta=0;
my $pitch=0;
my $roll=0;
my $yaw=0;
my $picnumber=0;
my $startpic=0;
my @gpslat=0;
my @gpslon=0;
my @getimet=0;

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
      # printf "time error verify ";
      # printf "time: %02f ",$utw_s;
       $utw_s = 0; 
       $utw_m = $utw_m + 1;
       #printf ( $utw_s);
       };
    #ensure proper leading zero for single digits
    $utw_m = sprintf("%02d",$utw_m);
    $utw_s = sprintf("%02d",$utw_s);
    #my $time = "$utw_h:$utw_m:$utw_s"; #Time UTC HHMMSS.mmm  303318000/60000=5055.3/60=84.255/24=3.510625
    
    $date_gps[0] = $utw_s;
    $date_gps[1] = $utw_m;
    $date_gps[2] = $utw_h;
    $date_gps[3] = $filepts[2]; #day
    $date_gps[4] = $filepts[1] -1; #month
    $date_gps[5] = $filepts[0]; #year
   # --$date[4]; # Note that the month numbers must be shifted: Jan = 0, Feb = 1
    # Convert to epoch time format
    my $time = timelocal(@date_gps);
    return $time;
} 


#my $mw = MainWindow->new( -title => 'LOG2GPX file converter tool' );  
my $mw = new MainWindow;
$mw->geometry("1200x800");#$mw->geometry("200x300");
$mw->title("LOG2GPX converter tool");

#A frame for the bottons
my $bframe = $mw->LabFrame(
		-label => "Waypoints", 	#A frame title

		-height => 50, 	#Frame height
		-width 	=> 1008, 	#Frame width

	)->place( -x => 980, -y => 0); #Location on the main windo	

#A frame for the waypoints
my $lframe = $mw->LabFrame(
		-label => "Tracklist", 	#A frame title

		-height => 800, 	#Frame height
		-width 	=> 1008, 	#Frame width

	)->place( -x => 10, -y => 60); #Location on the main window
	

#my $label = $mw -> Label(-text=>"Hello WOrld") -> pack();



#############################################################	
#############################################################	
#############################################################	
#############################################################	


my $table_frame = $lframe->Frame()->pack();
my $table = $table_frame->Table(-columns => 13,
                                -rows => 30,
                                -fixedrows => 1,
                                -scrollbars => 'oe',
                                -relief => 'raised');

my @headers = ( "Num" , "Name" , "Picture-time" ,"Pic-epoch", "GPS-Time" , "GPS-epoch", "Latitude" , "Longitude" , "Altitude" , "Pitch" , "Roll" , "Yaw");
                                

 #for(0..scalar @headers - 1)
foreach my $col (1..scalar @headers)
{
  my $tmp_label = $table->Label(-text => $headers[$col-1], -width => 8, -relief =>'raised');
  $table->put(0, $col, $tmp_label);
}
$table->pack();	








#############################################################	
#############################################################	
#############################################################	
#############################################################	
	


my $button1 = $bframe -> Button(-text => "Open LOG", -command => \&load_log_sub)-> pack();
my $button8 = $bframe -> Button(-text => "Open GPX", -command => \&load_gpx_sub)-> pack();

my $button2 = $bframe -> Button(-text => "Print gps points", -command => \&print_gps_points_sub)-> pack();
my $button3 = $bframe -> Button(-text => "Load picture", -command => \&read_picture_data_sub)-> pack();
my $button4 = $bframe -> Button(-text => "Print picture data", -command => \&print_picture_data_sub)-> pack();

my $button5 = $bframe -> Button(-text => "Generate GPX file", -command => \&generate_gpx_sub)-> pack();
my $button6 = $bframe -> Button(-text => "Generate photoscan file", -command => \&generate_photoscan_txt_sub)-> pack();

my $button7 = $bframe -> Button(-text => "Sync time", -command => \&sync_sub)-> pack();

my $button = $bframe -> Button(-text => "Quit", -command => sub { exit })-> pack();
MainLoop;
















sub load_log_sub {
#my $fname = $mw->getOpenFile( -title => 'Open LOG File:',-initialdir => '~' );
my $fname = $mw->getOpenFile( -title => 'Open LOG File:',-initialdir => '/media/eduardo/TRABALHO1/bahia/trecho41-45/trecho43' );
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

@filepts = split(/\_/,$filename);
#              day           mon           yaer
my $date = $filepts[2] . $filepts[1] . $filepts[0];
$date1 = 20 . $filepts[0] . "-" . $filepts[1] . "-" . $filepts[2] . "T" ;

#$date_gps[0] = $filepts[5];
#$date_gps[1] = $filepts[4];
#$date_gps[2] = $filepts[3];
$date_gps[3] = $filepts[2]; #day
$date_gps[4] = $filepts[1]; #month
$date_gps[5] = $filepts[0]; #year
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
    @gpslat[$picnumber] = $latitude;
    @gpslon[$picnumber] = $longitude;

    $altitude=$fields[6];   #altitude da foto
    @gpsalt[$picnumber] = $altitude;
    $pitch=$fields[9]/10;   #pitch da foto
    @gpspitch[$picnumber] = $pitch;
    $roll=$fields[8]/10;    #roll da foto
    @gpsroll[$picnumber] = $roll;
    $yaw=$fields[10]/10; #yaw da foto
    @gpsyaw[$picnumber] = $yaw;
    $utw=$fields[12];       #ITOW
    @utw[$picnumber] = $utw;
    $timet= getnmeatime();  #horario da foto
    @getimet[$picnumber]=$timet;
    $temp = localtime($timet);

    printf "Shot no:%.3i @getimet[$picnumber] $temp lat:%.6f lon=%.6f alt=%.d\n",$fields[3],@gpslat[$picnumber],@gpslon[$picnumber],@gpsalt[$picnumber];
    my $tmp_label = $table->Label(-text => @getimet[$picnumber],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($picnumber, 6, $tmp_label); 

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
my $fname = $mw->getOpenFile( -title => 'Open GPX File:',-initialdir => '~' );
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
printf TXTFILE "num,   name,     itow    ,     lat        , lon       ,ASL, pitch,roll , course\n"; 

my $sacc =0;
my $pacc =0;
my $pdop =0;
my $numSV =0;
#($year,$month,$day) = Monday_of_Week($week,"2010"); #TODO:use week and day to calculate date?

printf " \n Veio do array \n";
 $size = scalar @filename;;
    print "size of array: $size.\n"; 
for ($picnumber=1; $picnumber < $size; $picnumber = $picnumber + 1){
    $latitude =  @filelat[$picnumber];
    $longitude = @filelon[$picnumber];
    $altitude = @filealt[$picnumber];
    $pitch = @filepitch[$picnumber];
    $roll = @fileroll[$picnumber];
    $yaw = @fileyaw[$picnumber];
    $utw = @utw[$picnumber];
    $timet = @fetime[$picnumber];
    printf "Shot no:%.3i $timet lat:%.6f lon=%.6f alt=%.d\n",$picnumber,$latitude,$longitude,$altitude;
   
## grava arquivo para uso no photoscan ##
   printf TXTFILE "$picnumber,@filename[$picnumber],$timet, %.6f\ , %.6f, %.4i, %.3i, %.3i, %.3i\n",$latitude,$longitude,$altitude,$pitch,$roll,$yaw;
## fim grava arquivo para uso no photoscan ##
  }
print "$path$filename.txt generated \n";    
close TXTFILE;
} #fim generate_photoscan_txt_sub        
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
sub sync_sub {  
print "\nSincroniza fotos com gps time\n";
my $fotonum = scalar @filename;
my $gpsnum = scalar @getimet;
my $match = 0;
print "numero fotos: $fotonum.\n"; 
print "numero waypoints: $gpsnum.\n";

for ($f=0; $f < $fotonum; $f = $f + 1){  #para cada foto
#     my @fields = split(/ /,@lt[$f]);
#    print $f, " ", @filename[$f], "  time:", $fields[3], "\n ";
  for ($g=0; $g < $gpsnum; $g = $g + 1){  #para cada waypoint
  my $timetemp = @fetime[$f] + 65 ; #offset horario camera
   if ($timetemp == @getimet[$g]) { $hit = 1;}
     elsif ($timetemp +1 == @getimet[$g]) { $hit = 1;} 
      # elsif  ($timetemp +2 == @getimet[$g]) { $hit = 1;} 
     #  elsif ((@fetime[$f] >= $timetemp -2) && (@fetime[$f] <= $timetemp +2)) { $hit = 1;}
         else {$hit=0;}
   
   if ($hit == 1) {
    $match = $match + 1;
    @filelat[$f] = @gpslat[$g];
    @filelon[$f] = @gpslon[$g];
    @filealt[$f] = @gpsalt[$g];
    @fileroll[$f] = @gpsroll[$g];
    @filepitch[$f] = @gpspitch[$g];
    @fileyaw[$f] = @gpsyaw[$g];
    
    my $tmp_label;
    my $temp = sprintf(scalar localtime($timetemp));
        
    $tmp_label = $table->Label(-text => $temp,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
   # $table->put($f, 3, $tmp_label); 
    
    $tmp_label = $table->Label(-text => $timetemp,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 4, $tmp_label);

    my $temp = sprintf(scalar localtime(@getimet[$g]));

    $tmp_label = $table->Label(-text => $temp,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($f, 5, $tmp_label);
    
    
    $tmp_label = $table->Label(-text => @getimet[$g],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 6, $tmp_label);
    
    $tmp_label = $table->Label(-text => @filelat[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 7, $tmp_label);
    
    $tmp_label = $table->Label(-text => @filelon[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 8, $tmp_label);

    $tmp_label = $table->Label(-text => @filealt[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 9, $tmp_label);    
    
    $tmp_label = $table->Label(-text => @filepitch[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 10, $tmp_label);   
    $tmp_label = $table->Label(-text => @fileroll[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 11, $tmp_label);   
    $tmp_label = $table->Label(-text => @fileyaw[$f],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($f, 12, $tmp_label);       
   # print"match $match -> $f $g  @filename[$f] \n";
    
    
    
    
    }
  }
}
}#fim sync_sub
























sub print_gps_points_sub {

 $size = scalar @getimet;
 print "size of array: $size.\n"; 
  for ($n=1; $n < $size; $n = $n + 1){
  my $temp = @getimet[$n];
  print $n, " ", $temp, " ", @gpslat[$n], " ", @gpslon[$n], " ", @gpsalt[$n], "\n";
 
    # my $tmp_label = $table->Label(-text => $n,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    #$table->put($n, 1, $tmp_label);
 
   # my $tmp_label = $table->Label(-text => "   ",-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    #$table->put($n, 2, $tmp_label);

   # my $tmp_label = $table->Label(-text => "   ",-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    #$table->put($n, 3, $tmp_label);
    
   # my $temp = @getimet[$n] -18;
  #  my $temp1 = scalar localtime($temp);
   # my $tmp_label = $table->Label(-text => $temp1,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
   # $table->put($n, 5, $tmp_label);
    
  #  my $tmp_label = $table->Label(-text => @getimet[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 6, $tmp_label);  
  #  
  #  my $tmp_label = $table->Label(-text => @gpslat[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 7, $tmp_label);
    
  #  my $tmp_label = $table->Label(-text => @gpslon[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 8, $tmp_label);

   # my $tmp_label = $table->Label(-text => @gpsalt[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
   # $table->put($n, 9, $tmp_label);    
    
  #  my $tmp_label = $table->Label(-text => @gpspitch[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 10, $tmp_label);   
  #  my $tmp_label = $table->Label(-text => @gpsroll[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 11, $tmp_label);   
  #  my $tmp_label = $table->Label(-text => @gpsyaw[$n],-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
  #  $table->put($n, 12, $tmp_label);   

  }
 # $table->pack();	
}
   

   
   
   
   
   
   
   
   
sub read_picture_data_sub {
my $fname = $mw->getOpenFile( -title => 'Open LOG File:',-initialdir => '/media/eduardo/TRABALHO1/bahia/trecho41-45/trecho43/100_0409' );
my ($filename, $path, $suffix) = fileparse($fname, '\.[^\.]*');

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

#$tm = localtime;
my $exifTool = new Image::ExifTool;
opendir(DIR, $path) ;
@arr = readdir(DIR);
closedir(DIR);
$index = 1;
foreach(@arr) {
$f = $_;
$f1= $path.$f;
$file = $f1;
    
  if ($index >2) {
    @filename[$index-2]=$f; #coloca nome do arquivo na tabela
    $info = $exifTool->ImageInfo($file, 'DateTimeOriginal'); #pega data da foto no exif
    # Our data comes in the form "YEAR:MON:DAY HOUR:MIN:SEC".
    my @date = reverse(split(/[: ]/, $info->{'DateTimeOriginal'})); # divide o horario em varios campos
    my @date1 = reverse(split(/[ ]/, $info->{'DateTimeOriginal'}));
   # $lt =  @date1[1]." ".@date1[0];
    # utime() wants data in the exact opposite order, so we reverse().
    # Note that the month numbers must be shifted: Jan = 0, Feb = 1
    --$date[4];
    # Convert to epoch time format
    my $time = timelocal(@date);    
    @fetime[$index-2] = $time;  #guarda foto epoch time na lista
  $lt = scalar localtime($time);
    # Error Handling
    if (defined $exifTool->GetValue('Error')) {
      print "ERROR: Skipping '$file': " . $exifTool->GetValue('Error') . + "\n";
      next;
    }
   print "file $f updated at $time  $lt\n";
    my $tmp_label = $table->Label(-text => $index-2 ,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($index-2, 1, $tmp_label);     
 
    my $tmp_label = $table->Label(-text => $f ,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($index-2, 2, $tmp_label);
    
   # my $tmp_label = $table->Label(-text => $lt ,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
   # $table->put($index-2, 3, $tmp_label);    
    
    my $tmp_label = $table->Label(-text => @fetime[$index-2] ,-padx => 2,-anchor => 'w', -background => 'white', -relief => "groove");
    $table->put($index-2, 4, $tmp_label);  
    
  }
$index = $index + 1;
}

$table->pack();
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


