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
my %mediamap = ();
my %sessionmedialist = ();
my %sessionFlowList = ();

my %callstatelist = ();

my %activeCallList = ();
my %activeSessionList = ();
my %activeStreamList = ();
my %activeMediaList = ();

my $inblock=false;
my $block="";

$timestampformat = "^(20..-..-.. ..:..:..\.......)";
my $lastts = "";

@files = <appmanager*.log>;

#Find all the Call sessions
foreach $file (@files) {
  print "Parsing $file\n";
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
                        if($block=~/"app_data" . "target_id=(.*);.*"/){
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
                if($block=~/"app_data" . "target_id=(.*);.*"/){
                        my $session=$1;
                        my $entry="$lastts";
                        $block=~/"type".*?"(.*?)"/;
                        my $entry=$entry . " $1 " ;
                        if($block=~/"content".*?"(.*?)",/){$entry=$entry . "[content=$1]";}
                        if($block=~/"status".*?"(.*?)"/){$entry=$entry . "[status=$1]";}
                        if($block=~/"reason".*?"(.*?)"/){$entry=$entry . "[reason=$1]";}
                        #if($block=~/"transaction_id".*?"(.*?)"/){$entry=$entry . "[trans_id=$1]";}
                        if($block=~/"media_id".*?"(.*?)"/){$entry=$entry . "[media_id=$1]";}
                        if($block=~/".*?[audio|video]_uri".*?"(.*?)"/){$entry=$entry . "[file_uri=$1]";}
						if($block=~/"digits".*?"(.*?)"/){$entry=$entry . "[digits=$1]";}
                        $entry=$entry . "\n";
                        $sessionFlowList{$session}=$sessionFlowList{$session} . $entry;
                        $entry="";
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
        elsif($lookingforsession > 0){
            if(/$timestampformat.*Session..Session.. id. (.*)/){     
                    my $sessionid = $2;
                    $sessions[$lookingforsession]=$sessionid;
                    #print "sessions[$lookingforsession]=$sessionid \n";
                    $revsessions{$sessionid}=$lookingforsession;
                    $lookingforsession=0;
                    
                }
        }elsif($lookingforstream > 0){
            if(/$timestampformat.*ResourceManager..createStreamResource.. id. (.*)/){
                    my $streamid = $2;
                    $streams[$lookingforstream]=$streamid;
                    #print "streams[$lookingforstream]=$streamid \n";
                    $lookingforstream=0;
            }
        }
        elsif(/$timestampformat.*AppManager..onOffer.. call_id. (.*?),/){
           my $callid = $2;
           #print "callids[$globalindex]=$callid \n";
           $callids[$globalindex]= "$callid";
           $revcallids{$callid}=$globalindex;
           $lookingforsession=$globalindex;
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
        elsif(/$timestampformat.*CallResource..setState.. call_id. (.*), state. (.*)/){
            if(not defined $callstatelist{$2} ){
                $callstatelist{$2}="$3 @ $1";
            }else {
                $callstatelist{$2}=$callstatelist{$2}.",\n$3 @ $1";
            }
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
   }
   close (MYFILE);
}

my $index=1;
while($index < $globalindex ){
     print "{\n";
     print "\"GlobalIndex\" : \"$index\",\n";
     print "\"CallId\" : \"$callids[$index]\",\n";
     print "\"SessionId\" : \"$sessions[$index]\",\n";
     print "\"StreamId\" : \"$streams[$index]\",\n";
     print "\"ToTag\" : \"$totags[$index]\", \n";
     print "\"MediaSessions\" : \"$sessionmedialist{$sessions[$index]}\" ,\n";
     print "\"CallStateList\" : \n[\n$callstatelist{$callids[$index]} \n] ,\n";
     print "\"SessionFlowList\" : \n[\n$sessionFlowList{$sessions[$index]} \n] \n";
     print "}\n";
     
     print OUTFILE "{\n";
     print OUTFILE "\"GlobalIndex\" : \"$index\",\n";
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

#print active sessions
print "Active Calls:\n";
print OUTFILE "Active Calls:\n";
foreach my $key (sort keys %activeCallList) {
    print $key." @ ".$activeCallList{$key}."\n";
    print OUTFILE $key." @ ".$activeCallList{$key}."\n";
  }
  
print "Active Streams:\n";
print OUTFILE "Active Streams:\n";
foreach my $key (sort keys %activeStreamList) {
    print $key." @ ".$activeStreamList{$key}."\n";
    print OUTFILE $key." @ ".$activeStreamList{$key}."\n";
  }
print "Active Media Sessions:\n";
print OUTFILE "Active Media Sessions:\n";
foreach my $key (sort keys %activeMediaList) {
    print $key." @ ".$activeMediaList{$key}."\n";
    print OUTFILE $key." @ ".$activeMediaList{$key}."\n";
  }
print "Active Sessions:\n";
print OUTFILE "Active Sessions:\n";
  foreach my $key (sort keys %activeSessionList) {
    print $key." @ ".$activeSessionList{$key}."\n";
    print OUTFILE $key." @ ".$activeSessionList{$key}."\n";
  }

 close (OUTFILE);


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




