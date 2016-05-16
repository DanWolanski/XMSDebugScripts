#!/usr/bin/perl
print "Opening $ARGV[0] for parsing....\n";

$faildetect1 = "^(.*)appmanager:.*AppManager::onAckCreateStream.*failed to create stream, rejecting call.*";
$faildetect2 = "^(.*)xmserver:.*ERROR  MediaServer::onCreateStream.*Media not available.*";

$snmptrap= "^.*No access configuration - dropping trap..*";

$watchstr1="^(.*)ssp_x86Linux_boot: ADEC.* could not write packet to .*";
$startstr = "^(.*)root: Starting: nodecontroller.*";
$stopstr = "^(.*)root: Stopping: nodecontroller.*";

open (OUTFILE, ">report.out");

print OUTFILE "------------------------------------------------------------\n";

$errorcount = 0;
$errorthreshold = 10;
$errorts = "";
$inerror = 0;

$restartcount = 0;
$failcount = 0;
$watchcount = 0;
$inwatch = 0;
$linesparsed = 0 ;
open (MYFILE, $ARGV[0]);
 while (<MYFILE>) {
     $linesparsed++;
    if( $inerror != 1){
        #increment the error count when you see any of the lines that showcase the issue
            if(/$faildetect1/){
                    $errorcount++;
                    $errorts=$1;
            }
            elsif(/$faildetect2/){
                    $errorcount++;
                    $errorts=$1;
            }
            else{
            #decrement if you hit a line that doesn't show the issue
                $errorcount--;
            }

            if( $errorcount > $errorthreshold){
                #if we hit the error threshold then we need to trigger and save it
                print OUTFILE "$errorts - Error Detected via threshold\n";
				print "$errorts - Error Detected via threshold\n";
                $inerror=1;
                $failcount++;

            }elsif( $errorcount < 0){
                $errorcount = 0;
            }
            
        }
        
   #     if(/$snmptrap/){
   #         print OUTFILE "$_";
#			print "$_";
#       }

	if(/$watchstr1/){
		print OUTFILE "$1 - Watchstr1 ($_)\n";
		print "$1 - Watchstr1 ($_)\n";
		$watchcount++;
        $inwatch=1;
	}
	elsif(/$stopstr/){
            print OUTFILE "$1 - Stop detected\n";
#			print "$1 - Stop detected\n";
        }
	elsif(/$startstr/){
            if( $inerror == 1){
                print OUTFILE "$1 - Restart detected  (Recovering from Error)\n";
				print "$1 - Restart detected  (Recovering from Error)\n";
            }elsif( $inwatch == 1){
                print OUTFILE "$1 - Restart detected  (Watch Flag Seen)\n";
				print "$1 - Restart detected  (Watch Flag Seen)\n";
            } else {
                print OUTFILE "$1 - Restart detected (NOT restarting due to Error)\n";
				print "$1 - Restart detected (NOT restarting due to Error)\n";
            }
            
            #reset all the counters looking for next error
            $errorcount=0;
            $errorts="";
            $inerror=0;
            $inwatch=0;
            $restartcount++;
        }
        
        

 }
 print "\n\n$linesparsed lines parsed\n";
 print OUTFILE"\n\n$linesparsed lines parsed\n";
 
 print "Watch count = $watchcount\n";
 print OUTFILE "Watch count = $watchcount\n";
 
 print "Fail count = $failcount\n";
 print OUTFILE "Fail count = $failcount\n";
 
 print "Restart count = $restartcount\n";
 print OUTFILE "Restart count = $restartcount\n";
 close (MYFILE);
 close (OUTFILE);

