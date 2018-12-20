#!/usr/bin/perl

open (OUTFILE, ">AppmanMapper.out");

my @callids =  ('               callid               ');
my @sessions = ('              sessionid             ');
my %revsessions = ();
my @streams =  ('              streamid              ');
my $globalindex=1;
my @totags =   ('                totags              ');
my $loogingforsession=0;
my $lookingforstream=0;
my $lookingforconf=0;
my $lookingforcall=0;
my @restartList= ();

my $createconfentry = "";
my $createcallentry = "";
my $registerentry = "";

my %mediamap = ();
my %sessionmedialist = ();
my %sessionFlowList = ();
my %fileList = ();
my %callstatelist = ();
my %confmap = ();

my %sidmap = ();
my %revsidmap = ();
my %activetransaction = ();
my $confcount = 0;
my %activeCallList = ();
my %activeSessionList = ();
my %activeStreamList = ();
my %activeMediaList = ();
my %activeConfList = ();
my $inblock=false;
my $block="";

$timestampformat = "^(20..-..-.. ..:..:..\.......)";
my $lastts = "";
my $currentversion;
@files = <appmanager*.log>;

print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
     #save off the timestamp
     if(/$timestampformat.*/){
            $lastts=$1;
            }
        #track the block
        if($inblock == true){
            if(/^\}/){
                $inblock=false;
				#2018-12-19 13:41:32.091386 NOTICE Starting appmanager 3.5.22155 Built: Dec  7 2018 13:10:54
				if($block=~/NOTICE Starting appmanager (.*)/){
					$currentversion=$1;
					printf "    *********************************************\n    Detected appmanager start:\n       $lastts - $currentversion\n    *********************************************\n";
					printf OUTFILE "    *********************************************\n    Detected appmanager start:\n       $lastts - $currentversion\n    *********************************************\n";
					push @restartList , $$lastts - $currentversion ;
				}
				#transaction map update
				if($block=~/"transaction_id" . "(.*)"/){
					my $transid=$1;
					if($block=~/("type" : "ACK")/){
						#printf "Deleting $transid\n";
						delete $activetransaction{$transid};
					} else {
						#printf "Adding $transid\n";
						my $session="unknown";
						if($block=~/ sid:(.*) /){	$session = $sidmap{$1};	} 
						elsif($block=~/"gusid" : "(.*)"/){	$session = $sidmap{$1};	} 
						elsif($block=~/"call_id" : "(.*)"/){	$session = $1;	} 
						elsif($block=~/"conf_id" : "(.*)"/){	$session = $1;	} 
						elsif($block=~/"media_id" : "(.*)"/){	$session = $mediamap{$1};	} 
						$activetransaction{$transid}=$session;
						
					}
					
				}
                #parse all the blocks here
                if($block=~/"type" . .ANSWERED./){
                    #ANSWERED BLOCK
                    $block=~/"call_id" . "(.*)"/;
                    my $session=$1;
                    $block=~/"called_uri" . ".*;tag=(.*)",/;
                    my $totag=$1;
                    my $index = $revsessions{$session};
                    $totags[$index]=$totag;
                    #print "totags[$index]=$totag (session=$session)\n";
                }
				if($block=~/"type" . "OFFER"/){
                    #OFFER BLOCK
                    $block=~/"call_id" . "(.*)"/;
                    my $session=$1;
                    $block=~/"called_uri" . ".*;tag=(.*)",/;
                    $block=~/"gusid" . "(.*)"/;
					$gusid = $1;
					$sidmap{$gusid} = $session;
					$revsidmap{$session} = $gusid;
                }
				

                #check if block had media_id
                elsif($block=~/"media_id" . "(.*)"/){
                    my $mediaid=$1;
                    #print "Found mediaid $mediaid\n";

                    #check if mediaid already in map
                    if ( not defined $mediamap{$mediaid} ) {
                        #print "$mediaid not in the mediamap\n";
                        #ifit does check if has target session
                        if($block=~/"id" : "(.*)"/){
                            my $session=$1;
                            #put session into map
                            $mediamap{$mediaid}=$session;
                            if( not defined $sessionmedialist{$session} ){
                                $sessionmedialist{$session}=$mediaid;
                            } else {
                                $sessionmedialist{$session}=$sessionmedialist{$session}.",".$mediaid;
                            }
                            #print "mediamap{$mediaid}=$session\n";
                            #print "sessionmedialist{$session}=$sessionmedialist{$session}\n";
                        }
                    }
                }


                # Map out all the session messages
                #use this set for MSML
                if($block=~/"app_data".*?"target_id=(.*?);.*"/){
                        my $session=$1;
                         my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                #call_id messages
                } elsif($block=~/"call_id" : "(.*?)"/){
                        my $session=$1;
                        my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                #this is for REST or Common API
                } elsif($block=~/"app_data" : "(.*?)"/){
                        my $session=$1;
                        my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                        
                }# Check for the SID
				elsif($block=~/ sid:(.*) AppManager::sendToApi/){
				   my $sid = $1;
				   my $session=$sidmap{$sid};
				   my $entry="$lastts".print_parms($block) . "\n";
				   $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                   $entry="";
				}elsif($block=~/"id" : "(.*?)"/){
                        my $session=$1;
                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";

                #otherwise just use the Media ID
                } elsif($block=~/"media_id" : "(.*?)"/){
                        $session = $mediamap[$1];
                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                }elsif ($block=~/"type" : "CREATE_CALL"/){
                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";

                       # printf "Saving create Call for next block - $createcallentry \n";
                        $createcallentry = $entry;
                }
				


                if($block=~/"conf_id" : "(.*?)"/){
                        $session = $1 ;
                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;

                        $entry="";
                } #SAVE THE CREATE_CONF block
                elsif ($block=~/"type" : "CREATE_CONF"/){
                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";                        $createconfentry = $entry;
                        #printf "Saving create conf for next block - $createconfentry \n";

                }
                elsif ($block=~/"type" : "REGISTER"/){

                        my $entry="$lastts";
						my $entry="$lastts".print_parms($block) . "\n";
                        $registerentry = $entry;
                        #printf "Saving register entry for complete - $registerentry \n";

                }
                #end block parse
                $block="";
            }
            else{
                #Add the line to the block
                $block=$block . "   " . $_;
            }
        }
        if(/^\{/){
            $inblock=true
        }
        #are we looking for session
            
            if(/$timestampformat.*Session..Session.. id. (.*)/){
              my $sessionid = $2;

              if($lookingforsession > 0){

                    $sessions[$lookingforsession]=$sessionid;
                    #print "sessions[$lookingforsession]=$sessionid \n";
                    $revsessions{$sessionid}=$lookingforsession;
                    $lookingforsession=0;
                    }
                  }
			if(/$timestampformat.*sid.(.*) AppManager..onApiCreateCall.. session_id. (.*)/ ){
            #if(/$timestampformat.*AppManageronApiCreateCall.. session_id. (.*) /){
					  
					  my $sid=$2;
                      my $sessionid = $3;
					  $sidmap{$sid}=$sessionid;
					  $revsidmap{$sessionid} = $sid;
				
                      $sessionFlowList{$sessionid}=$sessionFlowList{$sessionid} . $createcallentry;
                      $createcallentry="";
                      #in 3pcc and outbound it uses the StreamId as the callID
                      my $callid = $sessionid;
                      #print "callids[$globalindex]=$callid \n";
                      $callids[$globalindex]= $callid;
                      $revcallids{$callid}=$globalindex;
                      $fileList{$callid}=$file;

                      $sessions[$globalindex]=$sessionid;
                      #print "sessions[$lookingforsession]=$sessionid \n";
                      $revsessions{$sessionid}=$globalindex;
                      $lookingforstream=$globalindex;
                      #putting this here for now, as may be outbound call, if we get to stream without all then is 3pcc
                      $lookingforcall=$globalindex;
                      ##increment global index on new calls
                      $globalindex++;


              }
			if(/$timestampformat.* ResourceManager::createCallResource.. id: (.*?)$/){
				
				#in this case another call was crated for the stream resource so the session is no longer the callid
				my $callid = $2;
				
				if($lookingforcall > 0 ){
					$callids[$lookingforcall]= $callid;
					$lookingforcall=0;
				 } #todo here grab it out based on the SID
			}
            if(/$timestampformat.*ResourceManager..createStreamResource.. id. (.*)/){
                if($lookingforstream > 0){
                    my $streamid = $2;
                    $streams[$lookingforstream]=$streamid;
                    #print "streams[$lookingforstream]=$streamid \n";
                    $lookingforstream=0;
                }
                if($lookingforcall > 0 ){
                  #didnt find a call, so clearing this out and will continue to use the sessionID as callid
                  $loogingforcall=0;
                }
        }

        #need to filter out the app registration
        if(/$timestampformat.*Session..onActivatedApiMsgCmd.. queue action . REGISTER.* session id . (.*)/){

        }


        if(/.*ResourceManager::createConfResource.. id: (.*)/){
                    my $confid = $1;

                      $sessionFlowList{$lookingforconf}=$sessionFlowList{$lookingforconf} . $createconfentry;
                      $createconfentry="";

                        $streams{$lookingforconf}=$confid;
                        $confmap{$confid} = $lookingforconf;
                        #print "streams[$lookingforconf]=$confid \n";
                        #print "confmap[$confid]=$lookingforconf \n";

                        $lookingforconf=0;
                        $confcount++;


        }
        elsif(/$timestampformat.*AppManager..onOffer.. call_id. (.*?),/){
           my $callid = $2;
           #print "callids[$globalindex]=$callid \n";
           $callids[$globalindex]= "$callid";
           $revcallids{$callid}=$globalindex;
           $lookingforsession=$globalindex;
           $fileList{$callid}=$file;
           ##increment global index on new calls
           $globalindex++;
           #Next line in log should be the Session::Session with the ID
        }

        elsif(/$timestampformat.*AppManager..onApiAccept.. call_id. (.*)/){
           my $callid = $2;
           #search for the global index for the callid
           my $index = 1;
           while( $index < $globalindex){
                if($callids[$index] eq $callid){
                    $lookingforstream=$index;
                    #print "callids[$index]=$callid, now looking for stream\n";
                    #short circuiting the loop
                    $index=$globalindex;
                }
                $index++;
            }
        }
        elsif(/$timestampformat.*AppManager..onApiAnswer.. call_id. (.*)/){
           my $callid = $2;
           #search for the global index for the callid
           my $index = 1;
           while( $index < $globalindex){
                if($callids[$index] eq $callid){
                    if(exists($streams[$index]) ) {
                        #print "Already has a stream!\n";
                    }else{
                        $lookingforstream=$index;
                        #print "callids[$index]=$callid, now looking for stream\n";
                        #short circuiting the loop
                        $index=$globalindex;
                    }
                }
                $index++;
            }
        }
        elsif(/$timestampformat.*CallResource..setState.. call_id. (.*), state. (.*)/){
            if(not defined $callstatelist{$2} ){
                $callstatelist{$2}="$3 @ $1";
            }else {
                $callstatelist{$2}=$callstatelist{$2}.",\n$3 @ $1";
            }
        }

        elsif(/$timestampformat.*AppManager::onApiCreateConference.. session_id: (.*)/){
            #print "$2 is looking for conference resource\n";
            $lookingforconf = $2;
        }
        #9-27 18:34:04.220297 DEBUG  Session::onCompletedApiMsgCmd() dequeue action : REGISTER, id : 1, session id : 44297766-250d-442d-beb1-057a960d083c
        elsif(/$timestampformat.*Session::onCompletedApiMsgCmd.* REGISTER.*, session id : (.*)/){
            #print "$2 the registercomplete\n";
              my $session = $2;
              $sessionFlowList{$session}=$sessionFlowList{$session} . $registerentry;
              $registerentry="";


        }


        #maintain active call list
        if(/$timestampformat.*ResourceManager..createCallResource.. id. (.*)/){
            $activeCallList{$2}=$1 ;
			#printf "Adding $1 to active call list\n";
        }elsif(/.*ResourceManager..destroyCallResource.. id: (.*)/){
            delete $activeCallList{$1} ;
			#printf "Removing $1 to active call list\n";
        }
        #maintain the active session list
        if(/$timestampformat.*Session..Session.. id. (.*)/){

            $activeSessionList{$2}=$1 ;
        }elsif(/.*Session..~Session.. id. (.*)/){
            delete $activeSessionList{$1} ;
        }
        #remove the Startup registration for the processes
        elsif(/$timestampformat.*AppManager::onAck.. action: REGISTER, id: (.*)/){
            #print "Removing $2 because of REGISTER\n";
            delete $activeSessionList{$2};
        }
        #another condition to pull out service register
        elsif(/.*Session..onCompletedApiMsgCmd.. dequeue action . REGISTER.*session id . (.*)/){
            delete $activeSessionList{$1} ;
        }

        #maintain active stream list
        if(/$timestampformat.*ResourceManager..createStreamResource.. id. (.*)/){
            $activeStreamList{$2}=$1 ;
        }elsif(/.*ResourceManager..destroyStreamResource.. id: (.*)/){
            delete $activeStreamList{$1} ;
        }

        #maintain active media list
        if(/$timestampformat.*ResourceManager..createMediaResource.. id. (.*)/){
            $activeMediaList{$2}=$1 ;
        }elsif(/.*ResourceManager..destroyMediaResource.. id. (.*)/){
            delete $activeMediaList{$1} ;
        }
        #maintain active conf list
        if(/$timestampformat.*ResourceManager..createConfResource.. id. (.*)/){
            $activeConfList{$2}=$1 ;
        }elsif(/.*ResourceManager..destroyConfResource.. id. (.*)/){
            delete $activeConfList{$1} ;
        }

   }
   close (MYFILE);
}

print "   Parsing Complete!\n";
print "   Last Timestamp processed = $lastts\n";
print OUTFILE "\nLast Timestamp processed = $lastts\n";

my $detectedcount = $globalindex - 1 ;
printf "\nFlows:\n";
print "    $detectedcount Call Flows detected\n";
print OUTFILE "\n\n==================================\n";
print OUTFILE "Call Flows (count=$detectedcount)\n";
print OUTFILE "==================================\n";
my $index=1;
while($index < $detectedcount ){

     print OUTFILE "{\n";
     print OUTFILE "\"GlobalIndex\" : \"$index\",\n";
     print OUTFILE "\"SID\" : \"$revsidmap{$sessions[$index]}\",\n";
     print OUTFILE "\"FileFirstFound\" : \"$fileList{$callids[$index]}\",\n";
     print OUTFILE "\"CallId\" : \"$callids[$index]\",\n";
     print OUTFILE "\"SessionId\" : \"$sessions[$index]\",\n";
     print OUTFILE "\"StreamId\" : \"$streams[$index]\",\n";
     print OUTFILE "\"ToTag\" : \"$totags[$index]\", \n";
     print OUTFILE "\"MediaSessions\" : \"$sessionmedialist{$sessions[$index]}\" ,\n";
     print OUTFILE "\"CallStateList\" : \n[\n$callstatelist{$callids[$index]} \n] ,\n";
     print OUTFILE "\"SessionFlowList\" : \n[\n$sessionFlowList{$sessions[$index]} \n] \n";
     print OUTFILE "}\n";
     $index++;
}

print "    $confcount Conference Flows detected\n";
print OUTFILE "\n\n==================================\n";
print OUTFILE "Conference Flows (count = $confcount)\n";
print OUTFILE "==================================\n";
foreach my $key (sort keys %confmap) {
     print OUTFILE "{\n";
     print OUTFILE "\"SessionId/ConfID\" : \"$confmap{$key}\",\n";
     print OUTFILE "\"ConfResource\" : \"$key\",\n";
     print OUTFILE "\"SessionFlowList\" : \n[\n$sessionFlowList{$confmap{$key}} \n] \n";
     print OUTFILE "}\n";
  }


print "\nActive Resources:\n";
 print OUTFILE "\n\n==================================\n";
print OUTFILE "Active Lists\n";
print OUTFILE "==================================\n";
#print active sessions
print "\n    Active Conferences:\n";
print OUTFILE "\nActive Conferences:\n";
if( keys %activeConfList) {

foreach my $key (sort keys %activeConfList) {
    print "    ";
    print $key." @ ".$activeConfList{$key}."\n";
    print OUTFILE $key." @ ".$activeConfList{$key}."\n";
  }
}else {
    print "    No Active Conferences Detected!\n";
    print OUTFILE "No Active Conferences Detected!\n";
}
print "\nActive Calls:\n";
print OUTFILE "\nActive Calls:\n";
if( keys %activeCallList) {

foreach my $key (sort keys %activeCallList) {
    print "    ";
    print $key." @ ".$activeCallList{$key}."\n";
    print OUTFILE $key." @ ".$activeCallList{$key}."\n";
  }
 }else {
    print "    No Active Calls Detected!\n";
    print OUTFILE "No Active Calls Detected!\n";
}
print "\nActive Streams:\n";
print OUTFILE "\nActive Streams:\n";
if( keys %activeStreamList) {

foreach my $key (sort keys %activeStreamList) {
    print "    ";
    print $key." @ ".$activeStreamList{$key}."\n";
    print OUTFILE $key." @ ".$activeStreamList{$key}."\n";
  }
  }else {
    print "    No Active Streams Detected!\n";
    print OUTFILE "No Active Streams Detected!\n";
}
print "\nActive Media Sessions:\n";
print OUTFILE "\nActive Media Sessions:\n";
if( keys %activeMediaList) {

foreach my $key (sort keys %activeMediaList) {
    print "    ";
    print $key." @ ".$activeMediaList{$key}."\n";
    print OUTFILE $key." @ ".$activeMediaList{$key}."\n";
  }
  }else {
    print "    No Active Media Sessions Detected!\n";
    print OUTFILE "No Active Media Sessions Detected!\n";
}
print "\nActive Transactions:\n";
print OUTFILE "\nActive Transactions:\n";
if( keys %activetransaction) {

  foreach my $key (sort keys %activetransaction) {
    print "    ";
    print $key." @ ".$activetransaction{$key}."\n";
    print OUTFILE $key." @ ".$activetransaction{$key}."\n";
  }
}else {
    print "    No Active Transactions Detected!\n";
    print OUTFILE "No Active Transactions Detected!\n";
}
print "\nActive Sessions:\n";
print OUTFILE "\nActive Sessions:\n";
if( keys %activeSessionList) {

  foreach my $key (sort keys %activeSessionList) {
    print "    ";
    print $key." @ ".$activeSessionList{$key}."\n";
    print OUTFILE $key." @ ".$activeSessionList{$key}."\n";
  }
}else {
    print "    No Active Sessions Detected!\n";
    print OUTFILE "No Active Sessions Detected!\n";
}

 close (OUTFILE);
 print "\n\n-------------------------------------------------------------------\n";
 print "\n All flows and Active sessions can be viewed in AppmanMapper.out\n";


################# SUBS #################
sub format_block{
    my ($block) = @_;

    $block =~ s/%3[a|A]/:/g;
    $block =~ s/\\r\\n/\n      /g;
    $block =~ s/\\t/    /g;
    $block =~ s/></>\n       </g;
    $block =~ s/\\\//\\/g;
    $block =~ s/\\\"/\"/g;

    return $block
}

sub get_entry_from_block{
    my ($block) = @_;

    $block =~ s/%3[a|A]/:/g;
    $block =~ s/\\r\\n/\n      /g;
    $block =~ s/\\t/    /g;
    $block =~ s/></>\n       </g;
    $block =~ s/\\\//\\/g;
    $block =~ s/\\\"/\"/g;

    return $block
}

sub print_parms {
	my ($input) = @_;
	my $output = "";
	my $sdp="";
	my $type="";
	my $dir="";
	if(($input=~/"transaction_id"/)&&($input!~/("ACK")/)) {$dir=" =>";}
    else {$dir=" <=";}
    	
	
	while ($input =~ /\"(.*)\" : \"(.*)\"/g) {
		my $key=$1;
		my $value=$2;
		
		
		if($key eq "type"){
			$type=" ".$value." ";
		}
		elsif($key eq "sdp"){
				$sdp="[sdp=\n    ".$value."]" ; 
				$sdp=~ s/\\r\\n/\n    /g;
			}
		else{
				$output= $output."[".$key."=".$value."]";
		}
		
    }
	#putting sdp here so it is last as it is real big
	return $dir.$type.$output.$sdp;

}