#!/usr/bin/perl
print "Opening $ARGV[0] for parsing....\n";

#threshold detects
#May 19 12:08:21 pvm2mrf1 appmanager: 2016-05-19 12:08:21.130529 ERROR  AppManager::onAckCreateStream() failed to create stream, rejecting call
#May 19 12:08:21 pvm2mrf1 xmserver: 2016-05-19 12:08:21.389067 ERROR  MediaServer::onCreateStream() Media not available. 
$failOnAck = "^(.*)appmanager.*AppManager..onAckCreateStream.*(failed to create stream, rejecting call).*";
$failCreateStream = "^(.*)xmserver.*ERROR.*MediaServer..onCreateStream.*(Media not available).*";

#May 22 09:52:46 localhost xmserver: 2016-05-22 09:52:46.298064 WARN   DeviceManager::allocIptDevice() device: iptB1T1073 unavailable
$failIptUnavailable = "^(.*)xmserver.*WARN.*DeviceManager..allocIptDevice.*device.(iptB1T1072 unavailable).*";

#one and done detects
#May 19 22:58:07 pvm2mrf1 ssp_x86Linux_boot: ADEC<1083> could not write packet to JB TS 92640 SRT 11580 Seq 579 PT 0 FPP 0
$FailADEC = "^(.*)ssp_x86Linux_boot.*(ADEC.* could not write packet to .*)";

#May 19 11:10:29 pvm2mrf1 snmptrapd[19643]: No access configuration - dropping trap.
$snmptrap = "^(.*)snmp.*No access configuration - dropping trap.*";


#nodecontroller/service start/stop

#May 20 14:47:52 pvm2mrf1 root: Stopping: nodecontroller 
#May 20 14:51:53 pvm2mrf1 root: Starting: nodecontroller 
$startstr = "^(.*)root. Starting. nodecontroller.*";
$stopstr = "^(.*)root. Stopping. nodecontroller.*";

#auto recover prints
#May 20 11:47:32 sut-1181 ssp_x86Linux_boot: handle_stuck_task(): WRK10_p0 restart
#May 20 11:47:32 sut-1181 ssp_x86Linux_boot: PTX(1): Restart audio encoder
$failSSPRTP = "^(.*)ssp_x86Linux_boot. (handle_stuck_task.*? restart)";
$recoverySSPRTP = "^(.*)ssp_x86Linux_boot. (.*? Restart audio encoder)";

#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: Worker 4 has exceeded is stuck threshold count. threshold: 25  currJobCount:19 stuckJobCount:25
#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: APLib.c.2348:handle_stuck_worker - worker 4 is stuck. Jobs on worker queue: 541
#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: kill_worker(): Cancel worker task
#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: kill_worker(): Delete worker task
#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: ap_create_worker_task(): Create work task:0x7fb19c000e48 Task_20_w4

$failSSPMedia = "^(.*)ssp_x86Linux_boot. (Worker.*?has exceeded is stuck threshold count. .*?)";
$recoverySSPMedia = "^(.*)ssp_x86Linux_boot. (.*handle_stuck_worker - worker .*? is stuck. Jobs on worker queue.*)";


##Strings to watch for and report
#May 19 20:08:47 bl-108-vm01 ssp_x86Linux_boot: ap_create_worker_task(): Create work task:0x7fb19c000e48 Task_20_w4
$watchSSPMedia = "^(.*)ssp_x86Linux_boot. (ap_create_worker_task.* Create work task.*? )";

#May 20 14:42:59 pvm2mrf1 root: failureWatchdog.sh detected a fault - Detected increase messages file Errors (OldCount=746775, NewCount=746885)
$watchFailureWatchdog = "^(.*)root.*(failureWatchdog.sh detected a fault).*";

open (OUTFILE, ">report.out");

print OUTFILE "------------------------------------------------------------\n";

my $errorcount = 0;
my $errorthreshold = 20;
my $errorts = "";
my $inerror = 0;
my $snmpcount = 0;
my $restartcount = 0;
my $failcount = 0;
my $watchcount = 0;
my $recoverycount = 0;
my $linesparsed = 0 ;


open (MYFILE, $ARGV[0]);
 while (<MYFILE>) {
     $linesparsed++;
#failures go here     
     #these a threshold errors, these are errors that may come up multiple time, but are only actual failures when they are seen in large quantities and over a long time.  
    if( $inerror != 1){
        #increment the error count when you see any of the lines that showcase the issue
            if(/$failOnAck/){
                    $errorcount++;
                    $errorts=$1;
            }
            elsif(/$failCreateStream/){
                    $errorcount++;
                    $errorts=$1;
            }
            elsif(/$failIptUnavailable/){
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
        if( $inerror != 1){
	       if(/$FailADEC/){
		      print OUTFILE "$1 - ($2)\n";
		      print "$1 - faildetect3, ($2)\n";
		      $failcount++;
              $inerror=1;
	       } 
           elsif(/$failSSPRTP/){
		      print OUTFILE "$1 - ($2)\n";
		      print "$1 - faildetect4 ($2)\n";
		      $failcount++;
              $inerror=1;
	       }
           elsif(/$failSSPMedia/){
              print OUTFILE "$1 - ($2)\n";
		      print "$1 - faildetect5 ($2)\n";
		      $failcount++;
              $inerror=1;
           }
        }
        
        if(/$snmptrap/){
            print OUTFILE "$1 - SNMP trap ($2)";
#			print "$_";
            $snmpcount++;
       }

        

#recovery
	if(/$recoverySSPRTP/){
           #reset all the counters looking for next error
            $errorcount=0;
            $errorts="";
            $inerror=0;
            $recovercount++;
            print OUTFILE "$1 - Recovery detected ($2)\n";
            print "$1 - Recovery detected ($2)\n";
    }
    elsif(/$recoverySSPMedia/){
            #reset all the counters looking for next error
            $errorcount=0;
            $errorts="";
            $inerror=0;
            $recovercount++;
            print OUTFILE "$1 - Recovery detected ($2)\n";
            print "$1 - Recovery detected ($2)\n";
    }
	elsif(/$stopstr/){
            print OUTFILE "$1 - Stop detected\n";
#			print "$1 - Stop detected\n";
        }
	elsif(/$startstr/){
            if( $inerror == 1){
                print OUTFILE "$1 - Restart detected  (Recovering from Error)\n";
				print "$1 - Restart detected  (Recovering from Error)\n";
            }else {
                print OUTFILE "$1 - Restart detected (NOT restarting due to Error)\n";
				print "$1 - Restart detected (NOT restarting due to Error)\n";
            }
            
            #reset all the counters looking for next error
            $errorcount=0;
            $errorts="";
            $inerror=0;
            $restartcount++;
        }
        
# other strings to watch and report
    if(/$watchSSPMedia/){
		print OUTFILE "$1 - $2\n";
		print "$1 - $2\n";
		$watchcount++;
        
	}
    elsif(/$watchFailureWatchdog/) {
    	print OUTFILE "$1 - $2\n";
		print "$1 - $2\n";
		$watchcount++;
    
    }

 }
 print "\n\n$linesparsed lines parsed\n";
 print OUTFILE"\n\n$linesparsed lines parsed\n";
 
 
 print "SNMP trap count = $snmpcount\n";
 print OUTFILE "SNMP trap count = $snmpcount\n";
 
 print "Watch count = $watchcount\n";
 print OUTFILE "Watch count = $watchcount\n";
 
 print "Fail count = $failcount\n";
 print OUTFILE "Fail count = $failcount\n";
 
 print "Recovery count = $recoverycount\n";
 print OUTFILE "Recovery count = $recoverycount\n";
 
 print "Restart count = $restartcount\n";
 print OUTFILE "Restart count = $restartcount\n";
 
 if($inerror==1){
    print "\nCurrent state is IN ERROR\n\n";
    print OUTFILE "\nCurrent state is IN ERROR\n\n";
 }else{
    print "\nCurrent state is NO ERROR\n\n";
    print OUTFILE "\nCurrent state is NO ERROR\n\n";
 }
 
 close (MYFILE);
 close (OUTFILE);

