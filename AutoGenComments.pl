#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";
open (MYFILE, $ARGV[0]);
open (OUTFILE, ">$ARGV[0].commented.out");
open (WEBSEQFILE, ">$ARGV[0].webseq.out");
open (CALLLISTFILE,">$ARGV[0].calllist.out");
open (NETANNCONFCOUNT,">$ARGV[0].netann.out");
open (SESSIONS,">$ARGV[0].sessions.out");
open (STREAMS,">$ARGV[0].streams.out");


print OUTFILE "File Commented by AutoComment marked with AC\n";

 while (<MYFILE>) {
 
#Support for lognote
	if(/.*LOGNOTE.*/){
		print OUTFILE "//AC $_";				
#Tags used by LogMerge		
#Get the start loggen info
	}elsif(/^.*Startline.*/){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		#remove the \n
		chomp;
		$block="$_\\n";
		
	}elsif(/^.*----------------------------------------.*/){
		print OUTFILE "$_\nAC*/\n";
		$inblock=0;
		
################ XMSREST PARSES ##################		
#start call
 	}elsif(/DEBUG.*Request URI = /){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		chomp;
		$block="$_\\n";
		
#end action
	}elsif(/DEBUG.*Content = /){
		print OUTFILE "$_ ";
		/^.{34}(.*)\[/;
		$block="$block $1";
		$inblock=1;
		$flushonnexttimestamp=1;
			
}elsif($flushonnexttimestamp && /^20..-..-..*(DEBUG|INFO)/){
		$block =~ s/&#xA;/\\n/g;
		$block =~ s/&#xD;//g;
		print WEBSEQFILE "App->XMS: $block\n";		
		$flushonnexttimestamp=0;
		$block="";
		$inblock=0;
		print OUTFILE "AC*/ \n$_";

#grab the Rest Register deregister
	}elsif(/Router::RegURI -Register Resource URI =/){
		print OUTFILE "//AC $_";
		print CALLLISTFILE $_;
	}elsif(/Router::DeRegURI -Unregister Resource/){
		print OUTFILE "//AC $_";
		print CALLLISTFILE $_;
#response code for PUT
	}elsif(/.*Call::Put\(\) Response/){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		chomp;
		$block="$_\\n";
		
		
	}elsif(/.*Call::Put\(\) Exit/){
		#$inblock=0;
		/^.{34}(.*?)\[/;
		$block="$block$1\n";
		$block =~ s/&#xA;/\\n/g;
		$block =~ s/&#xD;//g;
		print OUTFILE "$_AC*/\n";
		#$flushonnexttimestamp=1;
		
		print WEBSEQFILE "XMS->App: $block\n";		
		$block="";
		$inblock=0;
		
#response code for Get
	}elsif(/.*Call::Get\(\) Response/){
		print OUTFILE "/*AC\n";
		$inblock=1;
		chomp;
		$block="$_\\n";
		print OUTFILE "$_";
				
	}elsif(/.*Call::Get\(\) Exit/){
		#$inblock=0;
		/^.{34}(.*?)\[/;
		$block="$block$1\n";
		$block =~ s/&#xA;/\\n/g;
		$block =~ s/&#xD;//g;
		print OUTFILE "$_AC*/\n";
		#$flushonnexttimestamp=1;
		
		print WEBSEQFILE "XMS->App: $block\n";		
		$block="";
		$inblock=0;
		
#response code for Create conf
	}elsif(/.*Conference::GenXML\(\) Response/){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		chomp;
		$block="$_\\n";
		
				
	}elsif(/.*Conference::GenXML\(\) Exit/){
		print OUTFILE "$_AC*/\n";
		$inblock=0;
		/^.{34}(.*?)\[/;
		$block="$block $1\\n";
		$flushonnexttimestamp=1;
#response code
	}elsif(/.*SessionThread::run\(\) retCode =/){
		print OUTFILE "//AC $_";
		/^.{34}(.*?)\[/;
		$block="$block $1";
		$block =~ s/&#xA;/\\n/g;
		$block =~ s/&#xD;//g;
		print WEBSEQFILE "XMS->App: $block\n";
		$block="";

##############  XMS Server Logs  ##################	
#add IPM startmedia
 	}elsif(/IpmDevice::setLocalMediaInfo\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/IpmDevice::stopMedia\(\)/){
		print OUTFILE "//AC $_";
	}
	elsif(/IpmDevice::onStopped\(\)/){
		print OUTFILE "//AC ***************** MEDIA STOPPED!! *********************************\n";
		print OUTFILE "//AC $_";
	}elsif(/Sdp::choose\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/IpmDevice::setRemoteMediaInfo\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/MediaServer::setEncryption\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/MediaServer::setIce\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/StreamResource::setState\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/StreamResource::set.*Direction\(\) direction:/){
		print OUTFILE "//AC $_";
#The other Startmedia block
	}elsif(/.*IpmDevice::startMedia\(\)/){
		print OUTFILE "//AC $_";
	}elsif(/.*IpmDevice::onStartMedia\(\)/){
		print OUTFILE "//AC ***************** MEDIA STARTED!! *********************************\n";
		print OUTFILE "//AC $_";
#grab the Stream State
	}elsif(/DEBUG  StreamResource::setState\(\) state:/){
		print OUTFILE "//AC $_";
#grab the onStuns with USE-CANDIDATE
	}elsif(/.*StreamResource::onStun\(\) USE-CANDIDATE for.*/){
		print WEBSEQFILE "EndPoint->XMS: $_\n";
		print OUTFILE "//AC $_";
#grab MediaServer INFO prints
	}elsif(/IPMEV_GENERATEIFRAME/){
		print OUTFILE "//AC $_";
#grab Alarm
	}elsif(/Alarm/){
		print OUTFILE "//AC $_";
#grab Event
	}elsif(/Event/){
		print OUTFILE "//AC $_";
	}elsif(/DeviceManager::onDeviceEvent\(\)/){
		print OUTFILE "//AC $_";
#grab the version number
	}elsif(/NOTICE Starting xmserver/){
		print OUTFILE "//AC $_";
##############  APPManager Logs  ##################			
#add session
	}elsif(/DEBUG  AppManager::onApiCreateCall\(\) session_id:/){
		print OUTFILE "//AC $_";
#add create streamid
	}elsif(/AppManager::onApiCreateCall\(\) create stream, stream_id:/){
		print OUTFILE "//AC $_";
		print STREAMS "$_";
	}elsif(/DEBUG  AppManager::onApiAnswer\(\) create stream, stream_id:/){
		print OUTFILE "//AC $_";
		print STREAMS "$_";
#add  destroy stream
	}elsif(/DEBUG  AppManager::onHangup\(\) destroying stream, id:/){
		print OUTFILE "//AC $_";
		print STREAMS "$_";
#sessions
	}elsif(/DEBUG  Session::Session\(\) id:/){
		print OUTFILE "//AC $_";
		print SESSIONS "$_";
#add  destroy stream
	}elsif(/DEBUG  Session::~Session\(\) id:/){
		print OUTFILE "//AC $_";
		print SESSIONS "$_";
##############  RTCWeb Logs  ##################		
	}elsif(/INFO.*RtcWeb::.*/){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		chomp;
		$block="$_\\n";
		$flushonnexttimestamp=1;
		
		}elsif(/DEBUG  Message written to web:.*/){
		print OUTFILE "/*AC\n";
		print OUTFILE "$_";
		$inblock=1;
		chomp;
		$block="$_\\n";
		$flushonnexttimestamp=1;
############## NETANN PRINTS ##################	
	}elsif(/NetAnn::run/){
		print OUTFILE "//AC $_";
		print NETANNCONFCOUNT "$_";

	}elsif(/Count::/){
		print OUTFILE "//AC $_";
		print NETANNCONFCOUNT "$_";

	}elsif(/Conf::parseUri/){
		print OUTFILE "//AC $_";
		print NETANNCONFCOUNT "$_";

	}elsif(/Conference::add/){
		print OUTFILE "//AC $_";
		print NETANNCONFCOUNT "$_";

	}elsif(/Conference::remove/){
		print OUTFILE "//AC $_";
		print NETANNCONFCOUNT "$_";
############## MISC OTHER PRINTS ##################	
#Print out all ERRORS
	}elsif(/.*ERROR.*/){
		print OUTFILE "//AC $_";
#Add in blocks to the call
	}elsif($inblock==1){
		print OUTFILE "$_";
		if(/^.{34}(.*?)\[/){
		$block="$block\\n$1";
		}else{
		chomp;
		$block="$block\\n$_";
		}
		
		
	}else{
#print everything else	
		print OUTFILE "$_";
	}

 }
 close (MYFILE); 
 close (OUTFILE);
 close (CALLLISTFILE);
