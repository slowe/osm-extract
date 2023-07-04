#!/usr/bin/perl

$filename = $ARGV[0];


open(FILE,$filename);
@lines = <FILE>;
close(FILE);

for($i = 0 ; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	$lines[$i] =~ s/\s+/\t/g;
}

$area = "";
$geojson = "{\n";
$geojson .= "\t\"type\": \"FeatureCollection\",\n";
$geojson .= "\t\"features\":[\n";
$geojson .= "\t\t{ \"type\": \"Feature\", \"properties\": {\"name\": \"$lines[0]\" }, \"geometry\": { \"type\": \"MultiPolygon\", \"coordinates\": [[\n";
$npoly = 0;
$ncoord = 0;
for($i = 1 ; $i < @lines; $i++){

	if($lines[$i] =~ /^([^\s\t]+.*)$/ && $lines[$i] ne "END"){
		$area = $1;
		print "Area: $area\n";
		$geojson .= "\t\t\t[";
		$ncoord = 0;
	}elsif($lines[$i] eq "END"){
		if($area){
			$geojson .= "]";
			$npoly++;
			$area = "";
		}
	}else{
		if($area){
			$lines[$i] =~ s/^[\s\t]+//g;
			($lon,$lat) = split(/[\s\t]/,$lines[$i]);
			$geojson .= ($ncoord > 0 ? "," : "")."[$lon,$lat]";
			$ncoord++;
		}
	}
}
$geojson .= "\n\t\t]]\n";
$geojson .= "\t}}]\n";
$geojson .= "}\n";

$filename .= ".geojson";

print "Saving to $filename\n";



open(FILE,">",$filename);
print FILE $geojson;
close(FILE);