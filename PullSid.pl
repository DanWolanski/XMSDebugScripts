#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";
open (MYFILE, $ARGV[0]);
open (OUTFILE, ">$ARGV[0].parsed.out");
open (CONNECTIONSFILE, ">$ARGV[0].connections.out");


print OUTFILE "File Commented by AutoComment marked with AC\n";

 while (<MYFILE>) {
 
	if(/<msml/){
		#print OUTFILE "/*AC\n";
		#print OUTFILE "$_";
		$block="$_";
		$inblock=1;
	}elsif(/<\/msml>/){
		#print OUTFILE "$_AC*/\n";
		$block="$block $_ ";
		print OUTFILE $block;
		$block="";
		$inblock=0;
	}elsif($inblock==1){
		#print OUTFILE "$_";
		$block="$block $_";
	}elsif(/.*id=\"conn:(.*)\//){
		print CONNECTIONSFILE $1;
	}elsif(/No.     Time        Source                Destination           Protocol Length Info/){
		$block=$_;
		$getnextline=1;
	}elsif($getnextline){
		$block="$block $_";
		$getnextline=0;
		print OUTFILE $block;
		$block="";
	}
 }
 close (MYFILE); 
 close (OUTFILE);
 close (CONNECTIONSFILE) ;
