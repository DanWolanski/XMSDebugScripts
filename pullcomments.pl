#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";
open (MYFILE, $ARGV[0]);
open (OUTFILE, ">$ARGV[0].out");
 while (<MYFILE>) {
 	if(/^.*\/\/.*DMW/)
	{
 	print OUTFILE "$1\n";
	} else if(/\/\*.*DMW/){
		$inblock=1;
	 	print OUTFILE "$1\n";		
	} else if(/DMW.*\*\//){
		$inblock=0;
		print OUTFILE "$1\n";		
	} else if($inblock==1){
		print OUTFILE "$1\n";		
	}
 }
 close (MYFILE); 
 close (OUTFILE);
