#!/usr/bin/perl

open (OUTFILE, ">MSMLMapper.out");

my @sipcallids =  ();
my @sessions = ();
my @totags =   ();
my @streams =  ();

my %mediamap = ();
my %sessionmedialist = ();
my %sessionFlowList = ();
my %callstatelist = ();
my %dialoglist = ();
$timestampformat = "^(20..-..-.. ..:..:..\.......)";
my $lastts = "";

@files = <msmlserver*.log>;

#data for the XMSEventCallbacks
my $inXMSEventCallback=false;
my @XMSEventCallbackBlock=();
my @DispatchEventBlock = ();

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

    #First lets look for the Sip Call session from the XMS event callback logging
    #example of start of callback
    #2016-07-14 00:39:17.847949 DEBUG  ! 0x918ec700 ! XMS_MGR          ! CXMSMgr               ! L_ALL     !     1 ! ====> xms_event_callback()
    if(/$timestampformat DEBUG.*! ====> xms_event_callback../){
      $inXMSEventCallback=true;
    }
    if($inXMSEventCallback){
      #if in the block keep adding to string
      push @XMSEventCallbackBlock, $_ ;
      #check for end of block
      #2016-07-14 00:39:17.848671 DEBUG  ! 0x918ec700 ! XMS_MGR          ! CXMSMgr               ! L_ALL     !     1 ! <==== xms_event_callback()
      if(/$timestampformat DEBUG.*! <==== xms_event_callback../){
          parseXMSEventCallbackBlock(@XMSEventCallbackBlock);
          undef @XMSEventCallbackBlock;
          $inXMSEventCallback=false;
          next;
      }
    }

    #parsing dispatch event blocks
    #2016-07-14 00:39:18.029380 DEBUG  ! 0x90ae3700 ! EVENT_MGR        ! CEventMgr             ! L_ALL     !     1 ! ====> DispatchEvent()
    if(/$timestampformat DEBUG.*? ====> DispatchEvent../){
      $inDispatchEvent=true;
    }
    if($inDispatchEvent){
      #if in the block keep adding to string
      push @DispatchEventBlock, $_ ;
      #check for end of block
      #2016-07-14 00:39:18.030860 DEBUG  ! 0x90ae3700 ! EVENT_MGR        ! CEventMgr             ! L_ALL     !     1 ! <==== DispatchEvent() returns 0
      if(/$timestampformat DEBUG.*! <==== DispatchEvent.*/){
          parseDispatchEventBlock(@DispatchEventBlock);
          undef @DispatchEventBlock;
          $inDispatchEvent=false;
          next;
      }

    }

    #map out the dialogs
    #2016-07-14 00:39:18.506623 INFO   ! 0x90ae3700 ! TRANSACTION_MGR  ! CTransactionMgr       ! L_INFO    !     1 ! RegisterDialog() insert DialogId=conn:eb902a70-650b0a0a-13c4-65014-35-3e54ae6e-35/dialog:playPromptCollect into dialog map succeeded.
    #this is removing of dialog
    #2016-07-14 00:39:20.619911 INFO   ! 0x90ae3700 ! TRANSACTION_MGR  ! CTransactionMgr       ! L_INFO    !     1 ! UnregisterDialog() remove DialogId=conn:eb902a70-650b0a0a-13c4-65014-35-3e54ae6e-35/dialog:playPromptCollect from dialog map succeeded.
    if(/$timestampformat INFO .*? ((?:Unr|R)egister)Dialog.. (?:insert|remove) DialogId=(?:conn|conf):(.*?)\/dialog:(.*?) (?:into|from)/){
      my $timestamp = $1 ;
      my $action = $2 ;
        my $target = $3;
        my $dialog = $4;
        #print "dialoglist[$target] = $dialog - $action @ $timestamp\n";
        $dialoglist{$target} .= "$timestamp $dialog - $action \n";

    }

   }
   close (MYFILE);
}

print "   Parsing Complete!\n";
print "   Last Timestamp processed = $lastts\n";
print OUTFILE "\nLast Timestamp processed = $lastts\n";

my $count = @sessions ;
printf "\nFlows:\n";
print "    $count Call Flows detected\n";
print OUTFILE "\n\n==================================\n";
print OUTFILE "Call Flows (count=$count)\n";
print OUTFILE "==================================\n";
foreach my $session (@sessions){
     print OUTFILE "{\n";
     print OUTFILE "\"CallId\" : \"$sipcallids{$session}\",\n";
     print OUTFILE "\"SessionId\" : \"$session\",\n";
     print OUTFILE "\"ToTag\" : \"$totags{$session}\", \n";
     print OUTFILE "\"MediaSessionList\" : \n[\n$sessionmedialist{$session} \n] ,\n";
     print OUTFILE "\"CallStateList\" : \n[\n$callstatelist{$session} \n] ,\n";
     print OUTFILE "\"DialogList\" : \n[\n$dialoglist{$totags{$session}} \n],\n";
     print OUTFILE "\"SessionFlowList\" : \n[\n$sessionFlowList{$session} \n] \n";
     print OUTFILE "}\n";
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

sub parseXMSEventCallbackBlock{
    my @block = @_;

    #print "parsing XMSEventCallback block...\n";
    my $timestamp="";
    my %parms=();
    my $session;
    my $resource;

    my $lastkey = "";
    my $inparmbock = false ;
    foreach ( @block ){
      #this is used to signal that the end of multiline data
      if(/$timestampformat/){
          $lastkey="";
      }
      #if still in the block then we need to keep appending the data to same last key removing the newline
      elsif ($lastkey ne "" && /(.*)\n/){
        $parms{$lastkey} .= $1;
        next;
      }
      if(/log_xms_param.. - key=(.*?), value=(.*?)\n/){
      #   print "   $1 = $2\n";
          $parms{$1} = $2 ;
          $lastkey = $1 ;
      }
      
      if(/$timestampformat.*! ====> xms_event_callback../){
        $timestamp=$1;
        next;
      }


    }
      if( exists $parms{'app_data'}){
          $parms{'app_data'}=~/target_id=(.*?);resource_id=(.*?)\n/;
          if( grep ( /^$1$/ , @sessions) ){
            $session = $1;
            $resource = $2;
        }
      }

      if( exists $parms{'call_id'} ){
        $session = $parms{'call_id'};
        #if is new OFFER open MAP and start adding details
        if(exists $parms{'type'}  && $parms{'type'} eq 'OFFER' && exists $parms{'headers.Call-ID'} ){
            #print "   Adding " . $session ." to sessions\n";
            push @sessions , $session;
            #new call here, adding call to the sipcallmap
            #print "   Adding sipcallids[$session] = " . $parms{'headers.Call-ID'} ."\n";
            $sipcallids{$session}=$parms{'headers.Call-ID'};

        } #this is the accepted, pulling the totag
        elsif(exists $parms{'type'}  && $parms{'type'} eq 'ACCEPTED' && exists $parms{'called_uri'} ){
          $parms{'called_uri'}=~/.*tag=(.*)/;
          $totag = $1;
          #print "   Setting totags[$session] = $totag\n";
          $totags{$session} = $totag;
        }
    }

    #check for media_id, for now just filtering out the Media:xxx sessions, but TODO is to come back and map these.
    if( exists $parms{'media_id'} ){
      #check if it is in the list for the session
      if( grep( /$parms{'media_id'}/ , $sessionmedialist{$session}) ){
        #print "Already in media map\n";
      } else {
        #print "mediamap[$session]=$parms{'media_id'} \n";
        $sessionmedialist{$session} .= $parms{'media_id'}. "\n";
      }
    }
    #update sessionFlowList
    my $entry = $timestamp;
    $entry .= " " . $parms{'type'} . "  ";
    #add in all the parms you want to track here
    @entrykeys = ('ack', 'media', 'content', 'audio_uri', 'video_uri','digits','reason','status','duration','state','timeout','uri');
    foreach my $key ( @entrykeys){
      if( exists $parms{$key}){
        $entry .="[$key=" . $parms{$key} . "]";
      }
    }
    $entry .= "\n";
    #printf "   $entry";
    $sessionFlowList{$session} .= $entry;
      #print "finished parsing block\n";

}

sub parseDispatchEventBlock{
    my @block = @_;

    #print "parsing DispatchEvent block...\n";
    my $timestamp="";
    my %parms=();
    foreach ( @block ){
      if(/$timestampformat DEBUG.*? ====> DispatchEvent../){
        $timestamp=$1;
      }
      #2016-07-14 00:39:17.848805 INFO   ! 0x90ae3700 ! EVENT_MGR        ! CEventMgr             ! L_INFO    !     1 ! DispatchEvent():>, thread_id=1, event_queue_size=0, event_type=OFFER, source_id=4350070a-da79-41e8-8c26-38112ca28433, resource_id=4350070a-da79-41e8-8c26-38112ca28433
      elsif(/source_id=(.*?),/){
        $sourceid =  $1;
      }
      #2016-07-14 00:39:17.849497 INFO   ! 0x90ae3700 ! CALL_RES         ! Call:0                ! L_INFO    !     0 ! SetState - Transitioning from ENUM_ST_IDLE to ENUM_ST_OPENED
      elsif(/! SetState - Transitioning from ENUM_ST_.*? to ENUM_ST_(.*)\n/){
         #print "   " . $1 . " @ " . $timestamp . "\n";
         $callstatelist{$sourceid} .= $1 . " @ " . $timestamp . "\n";
      }

    }

    #print "finished parsing block\n";

}
