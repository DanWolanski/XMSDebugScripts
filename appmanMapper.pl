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
                        my $entry="$lastts";
						if(($block=~/"transaction_id"/)&&($block!~/("ACK")/)) {$entry=$entry . " =>";}
                        else {$entry=$entry . " <=";}
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        if($block=~/"content" . "(.*)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}
						if($block=~/"called_uri".*?"(.*?)"/){$entry=$entry . "[called_uri=$1]";}
						if($block=~/"caller_uri".*?"(.*?)"/){$entry=$entry . "[caller_uri=$1]";}
                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/".*?(audio|video|src)_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$2]";}
						            if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        if($block=~/"action".*?"(.*?)"/){$entry=$entry . "[action=$1]";}
                        if($block=~/"alarm".*?"(.*?)"/){$entry=$entry . "[alarm=$1]";}
                        if($block=~/"state".*?"(.*?)"/){$entry=$entry . "[state=$1]";}
                        if($block=~/"conf_id".*?"(.*?)"/){$entry=$entry . "[conf_id=$1]";}
                        if($block=~/"audio".*?"(.*?)"/){$entry=$entry . "[audio=$1]";}
                        if($block=~/"video".*?"(.*?)"/){$entry=$entry . "[video=$1]";}
                        if($block=~/"region".*?"(.*?)"/){$entry=$entry . "[region=$1]";}

                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                #call_id messages
                } elsif($block=~/"call_id" : "(.*?)"/){
                        my $session=$1;
                        my $entry="$lastts";

                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        if($block=~/"content" . "(.*)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}
						if($block=~/"called_uri".*?"(.*?)"/){$entry=$entry . "[called_uri=$1]";}
						if($block=~/"caller_uri".*?"(.*?)"/){$entry=$entry . "[caller_uri=$1]";}
                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/".*?(recording|audio|video|src)_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$2]";}
						if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        if($block=~/"action".*?"(.*?)"/){$entry=$entry . "[action=$1]";}
                        if($block=~/"alarm".*?"(.*?)"/){$entry=$entry . "[alarm=$1]";}
                        if($block=~/"state".*?"(.*?)"/){$entry=$entry . "[state=$1]";}
                        if($block=~/"conf_id".*?"(.*?)"/){$entry=$entry . "[conf_id=$1]";}
                        if($block=~/"audio".*?"(.*?)"/){$entry=$entry . "[audio=$1]";}
                        if($block=~/"video".*?"(.*?)"/){$entry=$entry . "[video=$1]";}
                        if($block=~/"region".*?"(.*?)"/){$entry=$entry . "[region=$1]";}
                        if($block=~/"media".*?"(.*?)"/){$entry=$entry . "[media=$1]";}

                        if($block=~/"mline".*?"(.*?)"/){$entry=$entry . "[mline=$1]";}
                        if($block=~/"mid".*?"(.*?)"/){$entry=$entry . "[mid=$1]";}
                        if($block=~/"candidate".*?"(.*?)"/){$entry=$entry . "[candidate=$1]";}
                        
                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                #this is for REST or Common API
                } elsif($block=~/"id" : "(.*?)"/){
                        my $session=$1;
                        my $entry="$lastts";
                        if(($block=~/"transaction_id"/)&&($block!~/("ACK")/)) {$entry=$entry . " =>";}
                        else {$entry=$entry . " <=";}
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        if($block=~/"content" . "(.*)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}
						if($block=~/"called_uri".*?"(.*?)"/){$entry=$entry . "[called_uri=$1]";}
						if($block=~/"caller_uri".*?"(.*?)"/){$entry=$entry . "[caller_uri=$1]";}
                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/"uri".*?"(.*?)"/){$entry=$entry . "[uri=$1]";}
                        if($block=~/".*?(recording|audio|video|src)_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$2]";}
						if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        if($block=~/"action".*?"(.*?)"/){$entry=$entry . "[action=$1]";}
                        if($block=~/"alarm".*?"(.*?)"/){$entry=$entry . "[alarm=$1]";}
                        if($block=~/"state".*?"(.*?)"/){$entry=$entry . "[state=$1]";}
                        if($block=~/"conf_id".*?"(.*?)"/){$entry=$entry . "[conf_id=$1]";}
                        if($block=~/"call_id".*?"(.*?)"/){$entry=$entry . "[call_id=$1]";}
                        if($block=~/"audio".*?"(.*?)"/){$entry=$entry . "[audio=$1]";}
                        if($block=~/"video".*?"(.*?)"/){$entry=$entry . "[video=$1]";}
                        if($block=~/"region".*?"(.*?)"/){$entry=$entry . "[region=$1]";}
                        if($block=~/"term_digits".*?"(.*?)"/){$entry=$entry . "[term_digits=$1]";}
                        if($block=~/"beep".*?"(.*?)"/){$entry=$entry . "[beep=$1]";}
                        if($block=~/"caption".*?"(.*?)"/){$entry=$entry . "[caption=$1]";}
                        if($block=~/"mute".*?"(.*?)"/){$entry=$entry . "[mute=$1]";}
                        if($block=~/"tx_mute".*?"(.*?)"/){$entry=$entry . "[tx_mute=$1]";}
                        if($block=~/"privilege".*?"(.*?)"/){$entry=$entry . "[privilege=$1]";}
                        if($block=~/"mode".*?"(.*?)"/){$entry=$entry . "[mode=$1]";}




                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
                #otherwise just use the Media ID
                } elsif($block=~/"media_id" : "(.*?)"/){
                        $session = $mediamap[$1];
                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        if($block=~/"content" . "(.*)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}

                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/".*?(audio|video|src)_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$2]";}
						if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        if($block=~/"action".*?"(.*?)"/){$entry=$entry . "[action=$1]";}
                        if($block=~/"alarm".*?"(.*?)"/){$entry=$entry . "[alarm=$1]";}
                        if($block=~/"state".*?"(.*?)"/){$entry=$entry . "[state=$1]";}
                        if($block=~/"conf_id".*?"(.*?)"/){$entry=$entry . "[conf_id=$1]";}
                        if($block=~/"audio".*?"(.*?)"/){$entry=$entry . "[audio=$1]";}
                        if($block=~/"video".*?"(.*?)"/){$entry=$entry . "[video=$1]";}
                        if($block=~/"region".*?"(.*?)"/){$entry=$entry . "[region=$1]";}

                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";

                }elsif ($block=~/"type" : "CREATE_CALL"/){
                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"ice".*?"(.*?)"/){$entry=$entry . "[ice=$1]";}
                        if($block=~/"encryption".*?"(.*?)"/){$entry=$entry . "[encryption=$1]";}
                        if($block=~/"signalling".*?"(.*?)"/){$entry=$entry . "[signalling=$1]";}
                        if($block=~/"sdp".*?"(.*?)"/){$entry=$entry . "[sdp=$1]";}
                        $entry=$entry . "\n";

                        #printf "Saving create conf for next block - $createconfentry \n";
                        $createcallentry = $entry;
                }


                if($block=~/"conf_id" : "(.*?)"/){
                        $session = $1 ;
                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        my $entry=$entry . " $1 " ;
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        if($block=~/"content" . "(.*)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}

                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/".*?(audio|video|src)_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$2]";}
						            if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        if($block=~/"action".*?"(.*?)"/){$entry=$entry . "[action=$1]";}
                        if($block=~/"alarm".*?"(.*?)"/){$entry=$entry . "[alarm=$1]";}
                        if($block=~/"state".*?"(.*?)"/){$entry=$entry . "[state=$1]";}
                        if($block=~/"audio".*?"(.*?)"/){$entry=$entry . "[audio=$1]";}
                        if($block=~/"video".*?"(.*?)"/){$entry=$entry . "[video=$1]";}
                        if($block=~/"region".*?"(.*?)"/){$entry=$entry . "[region=$1]";}
                        if($block=~/"call_id".*?"(.*?)"/){$entry=$entry . "[call_id=$1]";}
                        if($block=~/"media".*?"(.*?)"/){$entry=$entry . "[media=$1]";}
                        if($block=~/"layout".*?"(.*?)"/){$entry=$entry . "[layout=$1]";}
                        if($block=~/"layout_size".*?"(.*?)"/){$entry=$entry . "[layout_size=$1]";}

                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;

                        $entry="";
                } #SAVE THE CREATE_CONF block
                elsif ($block=~/"type" : "CREATE_CONF"/){

                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"media".*?"(.*?)"/){$entry=$entry . "[media=$1]";}
                        if($block=~/"layout".*?"(.*?)"/){$entry=$entry . "[layout=$1]";}
                        if($block=~/"layout_size".*?"(.*?)"/){$entry=$entry . "[layout_size=$1]";}
                        if($block=~/"caption".*?"(.*?)"/){$entry=$entry . "[caption=$1]";}
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        $entry=$entry . "\n";
                        $createconfentry = $entry;
                        #printf "Saving create conf for next block - $createconfentry \n";

                }
                elsif ($block=~/"type" : "REGISTER"/){

                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        $entry=$entry . " $1 " ;
                        if($block=~/"name".*?"(.*?)"/){$entry=$entry . "[name=$1]";}
                        if($block=~/"service".*?"(.*?)"/){$entry=$entry . "[service=$1]";}
                        if($block=~/"version".*?"(.*?)"/){$entry=$entry . "[version=$1]";}
                        if($block=~/"description".*?"(.*?)"/){$entry=$entry . "[description=$1]";}
                        if($block=~/"ack".*?"(.*?)"/){$entry=$entry . "[ack=$1]";}
                        $entry=$entry . "\n";
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
            if(/$timestampformat.*sid.(.*) AppManager..onApiCreateCall.. session_id. (.*)/){
                my $sid=$2;
                my $sessionid=$3;

                $sidmap{$sid}=$sessionid;
                $revsidmap{$sessionid} = $sid;
			
		   
			  $sessionFlowList{$sessionid}=$sessionFlowList{$sessionid} . $createcallentry;
			  $createcallentry="";
			  #in 3pcc and outbound it uses the StreamId as the callID
			  my $callid = $sessionid;
			  #print "callids[$globalindex]=$callid \n";
			  $callids[$globalindex]= "$callid";
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
			elsif(/$timestampformat.*AppManager::onApiCreateCall.. session_id: (.*)/){
                      my $sessionid = $2;
                      $sessionFlowList{$sessionid}=$sessionFlowList{$sessionid} . $createcallentry;
                      $createcallentry="";
                      #in 3pcc and outbound it uses the StreamId as the callID
                      my $callid = $sessionid;
                      #print "callids[$globalindex]=$callid \n";
                      $callids[$globalindex]= "$callid";
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

			if(/$timestampformat.*sid.(.*) Session..Session.. id. (.*)/){
			    my $sid=$2;
                my $sessionid=$3;

                $sidmap{$sid}=$sessionid;
                $revsidmap{$sessionid} = $sid;
			
            
              if($lookingforsession > 0){

                    $sessions[$lookingforsession]=$sessionid;
                    #print "sessions[$lookingforsession]=$sessionid \n";
                    $revsessions{$sessionid}=$lookingforsession;
                    $lookingforsession=0;
                    }
                  }
            elsif(/$timestampformat.*Session..Session.. id. (.*)/){
              my $sessionid = $2;

              if($lookingforsession > 0){

                    $sessions[$lookingforsession]=$sessionid;
                    #print "sessions[$lookingforsession]=$sessionid \n";
                    $revsessions{$sessionid}=$lookingforsession;
                    $lookingforsession=0;
                    }
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
        }elsif(/.*ResourceManager..destroyCallResource.. id: (.*)/){
            delete $activeCallList{$1} ;
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
if( keys %activeConfList) {
print "\n    Active Conferences:\n";
print OUTFILE "\nActive Conferences:\n";
foreach my $key (sort keys %activeConfList) {
    print "    ";
    print $key." @ ".$activeConfList{$key}."\n";
    print OUTFILE $key." @ ".$activeConfList{$key}."\n";
	
  }
}else {
    print "    No Active Conferences Detected!\n";
    print OUTFILE "No Active Conferences Detected!\n";
}

if( keys %activeCallList) {
print "\nActive Calls:\n";
print OUTFILE "\nActive Calls:\n";
foreach my $key (sort keys %activeCallList) {
    print "    ";
    print $key." @ ".$activeCallList{$key}."\n";
    print OUTFILE $key." @ ".$activeCallList{$key}."\n";
  }
 }else {
    print "    No Active Calls Detected!\n";
    print OUTFILE "No Active Calls Detected!\n";
}

if( keys %activeStreamList) {
print "\nActive Streams:\n";
print OUTFILE "\nActive Streams:\n";
foreach my $key (sort keys %activeStreamList) {
    print "    ";
    print $key." @ ".$activeStreamList{$key}."\n";
    print OUTFILE $key." @ ".$activeStreamList{$key}."\n";
  }
  }else {
    print "    No Active Streams Detected!\n";
    print OUTFILE "No Active Streams Detected!\n";
}

if( keys %activeMediaList) {
print "\nActive Media Sessions:\n";
print OUTFILE "\nActive Media Sessions:\n";
foreach my $key (sort keys %activeMediaList) {
    print "    ";
    print $key." @ ".$activeMediaList{$key}."\n";
    print OUTFILE $key." @ ".$activeMediaList{$key}."\n";
  }
  }else {
    print "    No Active Media Sessions Detected!\n";
    print OUTFILE "No Active Media Sessions Detected!\n";
}

if( keys %activeSessionList) {
print "\nActive Sessions:\n";
print OUTFILE "\nActive Sessions:\n";
  foreach my $key (sort keys %activeSessionList) {
    print "    ";
    print $key." @ ".$activeSessionList{$key}."\n";
    print OUTFILE $key." @ ".$activeSessionList{$key}."\n";
  }
}else {
    print "    No Active Sessions Detected!\n";
    print OUTFILE "No Active Sessions Detected!\n";
}

if( keys %activeSessionList) {
print "\nActive sid:\n";
print OUTFILE "\nActive sid:\n";
  foreach my $key (sort keys %activeSessionList) {
    print "    ";
    print "sid:".$key." @ ".$activeSessionList{$key}."\n";
    print OUTFILE "sid:".$key." @ ".$activeSessionList{$key}."\n";
  }
}else {
    print "    No Active sid Detected!\n";
    print OUTFILE "No Active sid Detected!\n";
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
