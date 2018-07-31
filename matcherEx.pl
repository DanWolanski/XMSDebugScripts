#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

#sould put the check for the other IDS in here to be sure
$startstr = "IpmDevice::stop.. stopping device:";
$stopstr = "IpmDevice::onStopped.. device: ";
$endstr = "^STOPHERESTRING";
$timestampstr = "^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{6})";
#$timestampstr = "^(20..-..-.. ..:..:..\.......)";
$idstr = " sid:([0-9,a-f]{32}) ";
$startotherinfostr = " ipmB1C([0-9]+)";
$stopotherinfostr = " ipmB1C([0-9]+)";

open (OUTFILE, ">matched.log");
open (CSVFILE, ">matched.csv");


@files = <xmserver*.log>;
print OUTFILE "Matching for \n     Timestamp=$timestampstr \n     ID=$idstr \n     Start=$startstr \n     Stop=$stopstr \n     End=$endstr \n     OtherInfo=$startotherinfostr \n ";
print "Matching for \n     Timestamp=$timestampstr \n     ID=$idstr \n     Start=$startstr \n     Stop=$stopstr \n     End=$endstr \n     OtherInfo=$startotherinfostr \n ";
print OUTFILE "------------------------------------------------------------\n";
print "------------------------------------------------------------\n";


my @matchedmap =  ('matchnumber,start time, stop time, pending count, sid, ipmdev');
my %pendingmap = ();
my $matchcount = 0;
my $pendingcount = 0;

print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
        if(/$endstr/){
              last;
        }
        elsif(/$startstr/){
			$logline = $_;
			$logline =~ /$idstr/;
			$id = $1;
			if(defined $pendingmap{$id}){
				print OUTFILE "ID $id is already in pending map - $pendingmap{$id} - $logline\n";
				print "ID $id is already in pending map \n";;
			} else {
				$pendingmap{$id}=$logline;
				$pendingcount++;
			}

        }
        elsif(/$stopstr/){
           $stopline = $_;
		   $stopline =~ /$idstr/;
		   $id = $1;
		   $startline = $pendingmap{$id};
		   if( defined $startline ){
			   #print "Start = $startline";
			   #print "Stop  = $stopline";
			   $matchcount++;
			   $startline =~ /$timestampstr/;			   
			   $starttime = $1;
			   $startline =~ /$startotherinfostr/;
			   $startotherinfo = $1;
			   $stopline =~ /$timestampstr/;
			   $stoptime = $1;
			   $stopline =~ /$stopotherinfostr/;
			   $stopotherinfo = $1;
			   $matchinfo = "$matchcount,$starttime,$stoptime,$pendingcount,$id,$startotherinfo";
			   $matchedmap[$matchcount]=$matchinfo;
	#		   print "$matchinfo\n";
			   delete $pendingmap{$id};
			   $pendingcount--;
		   }
		   else {
				print OUTFILE "Stop Detected without matching start - $stopline\n";
				print "ID $id has Stop Detected without matching start\n";
		   }
        }
        else{
			#don't care about this line
        }

	}
	close (MYFILE);
 }
 print "\n\nFinal count = $matchcount\n\n";
 print OUTFILE "\n\nFinal count = $matchcount\n\n";
 my $index=0;
 
while($index < $matchcount ){
	 #print "$matchedmap[$index]\n";
	 print OUTFILE "$matchedmap[$index]\n";
	 print CSVFILE "$matchedmap[$index]\n";
     $index++;
}
print OUTFILE "Matches written to matched.csv\n";
print "Matches written to matched.csv\n\n\n";
 
 close (OUTFILE);
 close (CSVFILE);

#2018-07-25 09:26:40.511373 DEBUG  sid:683a540c723c401b9805def64f8325ee IpmDevice::stop() stopping device: ipmB1C704
#2018-07-25 09:26:41.310857 INFO   sid:683a540c723c401b9805def64f8325ee IpmDevice::onStopped() device: ipmB1C704