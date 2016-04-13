#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";
open (MYFILE, $ARGV[0]);
open (OUTFILE, ">$ARGV[0].out");
 while (<MYFILE>) {
 	if(/{{{(.*)}}}/)
 	#if(/WebSequence/)
	{
 	print OUTFILE "$1\n";
	}
 }
 close (MYFILE); 
 close (OUTFILE);
