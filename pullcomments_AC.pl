#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";
open (MYFILE, $ARGV[0]);
open (OUTFILE, ">$ARGV[0].out.commentsonly");
 while (<MYFILE>) {
	$_ =~ s/&#xA;/\n/g;
	$_ =~ s/&#xD;/ /g;


 	if(/^.*\/\/.*AC(.*)/)
	{
 	print OUTFILE "$_";
	} elsif(/(.*)\/\*.*AC/){
		$inblock=1;
	 	print OUTFILE "$_";		
	} elsif(/.*\*\//){
		$inblock=0;
		print OUTFILE "$_";		
	} elsif($inblock==1){
		print OUTFILE "$_";		
	}
 }
 close (MYFILE); 
 close (OUTFILE);
