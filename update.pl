#!/usr/bin/perl

use POSIX qw(strftime);
use JSON::XS;
use Data::Dumper;


use Cwd qw(abs_path);

# Get the real base directory for this script
my $basedir = "./";
if(abs_path($0) =~ /^(.*\/)[^\/]*/){ $basedir = $1; }


$coder = JSON::XS->new->ascii->allow_nonref;

$config = loadConf($ARGV[0]||$basedir."config-wy.json");


$area = $config->{'area'};
$name = $area;
$name =~ s/\//\_/g;

$url = $config->{'pbf'};
$updateurl = $config->{'updates'};
$tdir = $basedir.$config->{'temp'};

$latest = $url;
$latest =~ s/^.*\/([^\/]+)(\.osm\.pbf)$/$1$2/g;
$latest = $tdir.$latest;
$old = $latest;
$old =~ s/\.osm/-old\.osm/;




if(!-e $latest){
	print "Download file from $url\n";
	`wget -O $latest "$url"`;
}

if(-e $latest){

	$tstamp = `osmconvert $latest --out-timestamp`;
	$tstamp =~ s/[\n\r]//g;
	print "PBF file last updated: $tstamp\n";


	# Move the file
	print "Move $latest > $old\n";
	`mv $latest $old`;
	# Update file
	print "Updating...\n";
	`osmupdate --tempfiles=$tdir --base-url=$updateurl --keep-tempfiles $old $latest`;

	if(!-e $latest){
		`mv $old $latest`;
	}

	if(-e $old){
		print "Remove old version from $old\n";
		`rm $old`;
	}


	foreach $a (keys(%{$config->{'areas'}})){

		print "$a:\n";
				
		if(!-e $basedir.$config->{'areas'}{$a}{'poly'}){
			error("No polygon file $config->{'areas'}{$a}{'poly'}\n");
		}
		$arealatest = $tdir.$a."-latest.o5m";
		# Make area extract
		print "OSM convert $arealatest.\n";
		`osmconvert $latest -B=$basedir$config->{'areas'}{$a}{'poly'} -o=$arealatest`;
		

		foreach $l (keys(%{$config->{'areas'}{$a}{'layers'}})){
			print "layer $l\n";

			# Extract layer
			$layer = $tdir.$a."-$l.osm";

			`osmfilter $arealatest --keep="$config->{'areas'}{$a}{'layers'}{$l}{'keep'}" -o=$layer`;
			$ldir = $basedir."layers/";
			if(!-d $ldir){
				`mkdir $ldir`;
			}

			$ldir .= $a."/";
			if(!-d $ldir){
				`mkdir $ldir`;
			}

			$geojson = $ldir."$l.geojson";

			saveGeoJSONFeatures($layer,$geojson);
			print "Remove $layer ";
			`rm $layer`;
		}
		`rm $arealatest`;
	}
}

exit;






sub saveGeoJSONFeatures {

	my (@types,@features,$t,@lines,$perl_scalar,$n,$i,$geojson,$txt,$bdir,$ini);
	
	my $osm = $_[0];
	my $ofile = $_[1];

	$bdir = $osm;
	$bdir =~ s/([^\/]+)$//;
	
	# Extract each feature type as GeoJSON
	@types = ('points','lines','multilinestrings','multipolygons','other_relations');

	@features = ();

	foreach $t (@types){
		$gfile = $bdir."temp-$t.geojson";
		$ini = $basedir."osmconf.ini";
		`ogr2ogr -overwrite --config OSM_CONFIG_FILE $ini -skipfailures -f GeoJSON $gfile $osm $t`;
		open(FILE,$gfile);
		@lines = <FILE>;
		close(FILE);
		$perl_scalar = $coder->decode(join("",@lines));
#		print Dumper $perl_scalar;
		$n = @{$perl_scalar->{'features'}};
		for($i = 0; $i < $n; $i++){
			# Process properties->other_tags into a structure
			if($perl_scalar->{'features'}[$i]{'properties'}{'other_tags'}){
				$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'} =~ s/\=\>/\:/g;
				$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'} = $coder->decode("{".$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'}."}");
			}
			
			push(@features,$perl_scalar->{'features'}[$i]);
		}
		`rm $gfile`;
	}
	$n = @features;
	$geojson = {'type'=>'FeatureCollection','features'=>\@features};
	
	$txt = $coder->canonical(1)->encode($geojson);
	$txt =~ s/(\{ ?"geometry":)/\n\t$1/gi;
	$txt =~ s/(\],"type":"FeatureCollection")/\n$1/;

	open(GEO,">",$ofile);
	print GEO $txt;
	close(GEO);	
	print "$n features in $ofile\n";

	return;
}

sub loadConf {
	# Version 1.1
	my ($file,$conf,$str,$coder,@lines);
	$file = $_[0];
	$str = "{}";
	if(-e $file){
		open(FILE,$file);
		@lines = <FILE>;
		close(FILE);
		$str = join("",@lines);
	}else{
		error("No config file $file = $ENV{'SERVER_NAME'}.");
	}
	$coder = JSON::XS->new->utf8->allow_nonref;
	eval {
		$conf = $coder->decode($str);
	};
	if($@){ error("Failed to load JSON from $file: $str");	}
	return $conf;
}


sub error {
	my $str = $_[0];
	print "Content-type: text/html\n\n";
	print "Error: $str\n";
	exit;
}






sub tidyTemporaryFiles {
	my $tstamp = substr($_[0],0,10);
	my ($dh,$filename,@files,$i,@lines,$line);

	print "Tidy $tstamp\n";
	
	opendir($dh,$tdir);
	while( ($filename = readdir($dh))) {
		if($filename =~ /\.d[0-9]+.txt$/){
			open($fh,$tdir.$filename);
			@lines = <$fh>;
			close($fh);
			foreach $line (@lines){
				if($line =~ /timestamp=([0-9]{4}-[0-9]{2}-[0-9]{2})/){
					if($1 lt $tstamp){
						print "Remove $filename\n";
#						`rm $tdir$filename`;
					}
				}
			}
		}
	}
	closedir($dh);
}
