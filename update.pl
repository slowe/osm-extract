#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(strftime);
use JSON::XS;
use Data::Dumper;

use Cwd qw(abs_path);

my ($basedir,$coder,$config,$area,$name,$url,$updateurl,$tdir,$latest,$old,$tstamp,$yesterday,$arealatest,$l,$layer,$modify,$ldir,$geojson,@addresses);

$basedir = $0;
$basedir =~ s/[^\/]*$//g;
if(!$basedir){ $basedir = "./"; }

$coder = JSON::XS->new->ascii->allow_nonref;

$config = loadConf($ARGV[0]||$basedir."config-wy.json");


$area = $config->{'area'};
$name = $area;
$name =~ s/\//\_/g;

$url = $config->{'pbf'};
$updateurl = $config->{'updates'};
$tdir = $basedir.$config->{'temp'};

if(!-d $tdir){
	`mkdir $tdir`;
}




$latest = $url;
$latest =~ s/^.*\/([^\/]+)(\.osm\.pbf)$/$1$2/g;
$latest = $tdir.$latest;
$old = $latest;
$old =~ s/\.osm/-old\.osm/;


if(-e $latest){
	$tstamp = `osmconvert $latest --out-timestamp`;
	$tstamp =~ s/[\n\r]//g;
}else{
	$tstamp = "2000-01-01";
}

$yesterday = strftime("%F",gmtime(time-86400));

if(!-e $latest || $tstamp lt $yesterday){

	if(-e $latest){
		# Move the file
		msg("Move <cyan>$latest<none> > <cyan>$old<none>\n");
		`mv $latest $old`;
	}

	msg("Download file from <green>$url<none> to <cyan>$latest<none>\n");
	`wget -q --no-check-certificate -O $latest "$url"`;
}

if(-e $latest){

	$tstamp = `osmconvert $latest --out-timestamp`;
	$tstamp =~ s/[\n\r]//g;
	msg("PBF file last updated: <yellow>$tstamp<none>\n");

#	# Update file
#	print "Updating...\n";
#	`osmupdate --tempfiles=$tdir --base-url=$updateurl --keep-tempfiles $old $latest`;
#
#	if(!-e $latest){
#		`mv $old $latest`;
#	}

	if(-e $old){
		msg("Remove old version from <cyan>$old<none>\n");
		`rm $old`;
	}

	foreach $a (keys(%{$config->{'areas'}})){

		msg("Area <yellow>$a<none>:\n");
		@addresses = ();

		if(!-e $basedir.$config->{'areas'}{$a}{'poly'}){
			error("No polygon file $config->{'areas'}{$a}{'poly'}\n");
		}
		$arealatest = $tdir.$a."-latest.o5m";
		# Make area extract
		msg("\tosmconvert $latest -B=$basedir$config->{'areas'}{$a}{'poly'} -o=$arealatest.\n");
		`osmconvert $latest -B=$basedir$config->{'areas'}{$a}{'poly'} -o=$arealatest`;
		

		foreach $l (sort(keys(%{$config->{'areas'}{$a}{'layers'}}))){
			msg("\tLayer <yellow>$l<none>:\n");

			# Extract layer
			$layer = $tdir.$a."-$l.osm";
			
			$modify = "";
			if($config->{'areas'}{$a}{'layers'}{$l}{'keep'}){ $modify .= " --keep=\"$config->{'areas'}{$a}{'layers'}{$l}{'keep'}\""; }
			if($config->{'areas'}{$a}{'layers'}{$l}{'drop'}){ $modify .= " --drop=\"$config->{'areas'}{$a}{'layers'}{$l}{'drop'}\""; }

			msg("\t\tosmfilter $arealatest $modify -o=$layer\n");
			`osmfilter $arealatest $modify -o=$layer 2>&1`;
			$ldir = $basedir."layers/";
			if(!-d $ldir){
				`mkdir $ldir`;
			}

			$ldir .= $a."/";
			if(!-d $ldir){
				`mkdir $ldir`;
			}

			$geojson = $ldir."$l.geojson";

			#if($layer =~ /craft/){
			saveGeoJSONFeatures($layer,$geojson,$tstamp,$config->{'areas'}{$a}{'layers'}{$l});
			#}

			if(-e $layer){
				msg("\t\tRemove $layer\n");
				`rm $layer`;
			}
		}
		if(-e $arealatest){
			`rm $arealatest`;
		}
	}
}


sub checkFeature {
	my $f = shift;
	my $l = shift;
	my (@keep,$key,$value,$oldkey,$b,$i,$ok,$str);

	$str = $l->{'keep'};
	$str =~ s/ or / /g;
	
	my @bits = split(/\s/,$str);
	for($b = 0; $b < @bits; $b++){
		($key,$value) = split(/=/,$bits[$b]);
		if(!$key){ $key = $oldkey; }
		$value =~ s/ $//g;
		push(@keep,{'key'=>$key,'value'=>$value});
		$oldkey = $key;
	}
	$ok = 0;
	for($i = 0; $i < @keep; $i++){
		$value = $keep[$i]->{'value'};
		$value =~ s/\*/\.\*/g;
		if(defined($f->{'properties'}{$keep[$i]->{'key'}})){
			if($value){
				if($f->{'properties'}{$keep[$i]->{'key'}} =~ /$value/){
					$ok++;
				}
			}else{
				$ok++;
			}
		}
		if(defined($f->{'properties'}{'other_tags'}{$keep[$i]->{'key'}})){
			if($value){
				if($f->{'properties'}{'other_tags'}{$keep[$i]->{'key'}} =~ /$value/){
					$ok++;
				}
			}else{
				$ok++;
			}
		}
	}
	return $ok;
}



sub saveGeoJSONFeatures {

	my (@types,@features,$t,@lines,$perl_scalar,$n,$i,$geojson,$txt,$bdir,$ini,$osm,$ofile,$tstamp,$props,$gfile);
	
	$osm = shift;
	$ofile = shift;
	$tstamp = shift;
	$props = shift;

	$bdir = $osm;
	$bdir =~ s/([^\/]+)$//;
	
	# Extract each feature type as GeoJSON
	@types = ('points','lines','multilinestrings','multipolygons','other_relations');

	@features = ();

	foreach $t (@types){
		$gfile = $bdir."temp-$t.geojson";
		$ini = $basedir."osmconf.ini";
		`ogr2ogr -overwrite --config OSM_CONFIG_FILE $ini -skipfailures -f GeoJSON $gfile $osm $t 2>&1`;
		open(FILE,$gfile);
		@lines = <FILE>;
		close(FILE);
		$perl_scalar = $coder->decode(join("",@lines));
		$n = @{$perl_scalar->{'features'}};
		for($i = 0; $i < $n; $i++){
			# Process properties->other_tags into a structure
			if(defined($perl_scalar->{'features'}[$i]{'properties'}{'other_tags'})){
				$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'} =~ s/\=\>/\:/g;
				$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'} = $coder->decode("{".$perl_scalar->{'features'}[$i]{'properties'}{'other_tags'}."}");
			}
			if(checkFeature($perl_scalar->{'features'}[$i],$props)){
				push(@features,$perl_scalar->{'features'}[$i]);
			}
		}
		if(-e $gfile){
			`rm $gfile`;
		}
	}
	$n = @features;
	$geojson = {'type'=>'FeatureCollection','features'=>\@features};

	$txt = $coder->canonical(1)->encode($geojson);
	$txt =~ s/(\{ ?"geometry":)/\n\t$1/gi;
	$txt =~ s/(\],"type":"FeatureCollection")[^\}]*?\}/\n$1\}/;
	$txt =~ s/,"other_tags":\{\}//g;

	open(GEO,">",$ofile);
	print GEO $txt;
	close(GEO);	
	msg("\t\t<yellow>$n<none> features in <cyan>$ofile<none>\n");

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

sub msg {
	my $str = $_[0];
	my $dest = $_[1]||"STDOUT";
	
	my %colours = (
		'black'=>"\033[0;30m",
		'red'=>"\033[0;31m",
		'green'=>"\033[0;32m",
		'yellow'=>"\033[0;33m",
		'blue'=>"\033[0;34m",
		'magenta'=>"\033[0;35m",
		'cyan'=>"\033[0;36m",
		'white'=>"\033[0;37m",
		'none'=>"\033[0m"
	);
	foreach my $c (keys(%colours)){ $str =~ s/\< ?$c ?\>/$colours{$c}/g; }
	if($dest eq "STDERR"){
		print STDERR $str;
	}else{
		print STDOUT $str;
	}
}

sub error {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<red>ERROR:<none> /;
	msg($str,"STDERR");
}

sub warning {
	my $str = $_[0];
	$str =~ s/(^[\t\s]*)/$1<yellow>WARNING:<none> /;
	msg($str,"STDERR");
}


sub tidyTemporaryFiles {
	my $tstamp = substr($_[0],0,10);
	my ($dh,$filename,@files,$i,@lines,$line,$fh);

	msg("Tidy <yellow>$tstamp<none>\n");
	
	opendir($dh,$tdir);
	while( ($filename = readdir($dh))) {
		if($filename =~ /\.d[0-9]+.txt$/){
			open($fh,$tdir.$filename);
			@lines = <$fh>;
			close($fh);
			foreach $line (@lines){
				if($line =~ /timestamp=([0-9]{4}-[0-9]{2}-[0-9]{2})/){
					if($1 lt $tstamp){
						msg("Remove <cyan>$filename<none>\n");
#						`rm $tdir$filename`;
					}
				}
			}
		}
	}
	closedir($dh);
}
