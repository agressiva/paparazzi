# tp=tamanho do pixel na terra
# u=tamanho do pixel no CCD
# lma=lado maior da foto
# lme=lado menor da foto
# altitude=altitude de voo
# Esses sao os dados .
# Distancia focal=16mm (tanto na foto quanto no manual)
# 23.5x15.6mm (APS-C)
# resolução: 4912 x 3264

my $SENSOR_WIDTH=6.17; #largura do sensor em mm
my $PIXELS_WIDTH=4000; #resolucao do sensor em pixels
my $PIXELS_HEIGHT=3000; #resolucao do sensor em pixels
my $FOCAL_LENGHT=5; #distancia focal em mm

my $altura=0; #altura do voo
my $tamanho_pixel=0;
my $lado_maior=0;
my $lado_menor=0;
my $u=0;
my $distancia_faixa=0;
my $disparo =0;
my $area_foto=0;

printf  "Cálculo de área para Câmera Canon SX200 12mpix\n";
$u = $SENSOR_WIDTH / $PIXELS_WIDTH;
$altura = 200; #InputBox ("Digite a altitude de vôo")
#recobertura = InputBox ("Digite o recobrimento entre fotos")

$tamanho_pixel = $u * $altura / $FOCAL_LENGHT;
$lado_maior = $tamanho_pixel * $PIXELS_WIDTH;
$lado_menor = $tamanho_pixel * $PIXELS_HEIGHT;
$area_foto = ($lado_maior*$lado_menor)/10000;
$distancia_faixa = $lado_maior * 0.4;
$disparo = $lado_menor * 0.3;

printf"\n";
printf "resolucao terreno:"; printf $tamanho_pixel*100; printf"cm\n";
printf "area da foto:"; printf $area_foto*100; printf"m2\n";
printf "Distancia entre faixas: "; printf $distancia_faixa; printf"m\n";
printf "Distancia entre disparos: "; printf $disparo; printf"m\n";

#'"Distancia do CP Longitudinal = " & recolong & "%" & chr(10) &_
#'"Distancia do CP Lateral = " & recolate & "%" & chr(10) &_
#	 ' printf("\n\nTamanho do pixel: %f",tp);
#'		  getch();