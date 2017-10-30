#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
my $command;
print "Introduce the input file (with complete path) for CCfinder? ";
my $path = <STDIN>;
my $i;
my $name;

chomp ($path);
my $new_path = split (/\\/, $path);
for $i (0 .. $#main::new_path) {
    $path = $main::new_path[i] . "/"}
open FILEHANDLE, $path or die;
open INPUT, ">inputFiles.txt" or die;

$name = "ccfinder java -i \"" . $path . "\" -o clonesOutput.txt";
print "$name \n";
print "executing CCfinder...\n";
$command = '$name';
print "executing CCReformer...\n";
$command = 'ccreformer class clonesOutput.txt -o classesOutput.txt';
print "executing my script...\n";
$command = 'perl version2.pl';