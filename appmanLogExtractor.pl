#!/usr/bin/perl

open (OUTFILE, ">appmanagerExtract.out");

print OUTFILE "------------------------------------------------------------\n";
print "------------------------------------------------------------\n";

print OUTFILE "Search strings are: \n";
print "Search strings are: \n";
foreach my $a (@ARGV) {
	print "$a\n";
    print OUTFILE "$a\n"; 
}
print OUTFILE "------------------------------------------------------------\n";
print "------------------------------------------------------------\n";

my %sessions = ();
my %sessionbuffers=();
$timestampformat = "^(20..-..-.. ..:..:..\.......)";
$filecount=0;
$pulltotal=0;
@files = <appmanager*.log>;


foreach $file (@files) {
  print "parsing" . $file . "\n";
  
  $linesparsed = 0 ;
  $pullcount = 0;
  $filecount++;
  open (MYFILE, $file);
  $lastts="";
  $inblock=0;
  $block="";
  
   while (<MYFILE>) {
         $linesparsed++;
         
         if(/$timestampformat/){
            $lastts=$1 . "\n";
            }
        
        if(/^\{/){
            $block=$lastts;
            $inblock=1;
        }elsif(/^\}/){
            $inblock=0;
            $block=format_block($block);
            
            if( $block=~ /\"app_data\" \: \"session_id=(.*?);resource_id=(.*?)\"/ ) {
                        my $session_id = $1;
                        if (! $sessions{$session_id}  > 0 ) {                            
                            $sessions{$session_id}=0;                            
                            
                        } 
                            $sessionbuffers{$session_id}=$sessionbuffers{$session_id} . $block . "\n";
                        
                        #maintain a buffer until we see first issue, once watch hit keep all of them
                        if ( ! $sessions{$session_id}  > 0 ) {
                            
                            #    if(@{$sessionbuffers{$session_id}} > 20){
                            #        #open (CALLFILE, "+>>session-" . $session_id . ".out");
                            #        #print CALLFILE $sessionbuffers{$session_id};                            
                            #        #close (CALLFILE);    
                            #        pop @{$sessionbuffers{$session_id}} ;
                            #    }    
                            }
                            #todo put check for end of session to see if it was flagged and if not reclaim memory
                    }
                    
            if(@ARGV < 1){
                $pullcount++;
                if($pullcount==1){
                    print OUTFILE "parsing" . $file . "\n";
                }
                
                print OUTFILE $block . "\n";
                if( $block=~ /\"app_data\" \: \"session_id=(.*?);resource_id=(.*?)\"/ ) {
                    my $session_id = $1;
                    $sessions{$session_id}='1';
                    
                }
                
            }else{
                foreach $searchstr (@ARGV) {
                if (index($block, $searchstr) != -1) {
                    $pullcount++;
                    
                    if($pullcount==1){
                        print OUTFILE "parsing" . $file . "\n";
                    }             
                    print OUTFILE "$block" . "\n";
                   if( $block=~ /\"app_data\" \: \"session_id=(.*?);resource_id=(.*?)\"/ ) {
                        my $session_id = $1;
                        $sessions{$session_id}++;    
                        #open (CALLFILE, "+>>session-" . $session_id . ".out");
                        #print CALLFILE $block;                            
                        #close (CALLFILE);
                            
                    }
                    last;
                    }
                }
            }
            $block="";
        }else{
            if ($inblock == 1){
                $block=$block . "   " . $_;
            }
        }
   }
        
               
 print "\n$linesparsed lines parsed\n";
 #print OUTFILE "$linesparsed lines parsed\n";
 print "$pullcount messages pulled\n\n";
 #print OUTFILE "$pullcount messages pulled\n\n";
 $pulltotal += $pullcount;
 
 close (MYFILE);
 }
 print "\n\n--------------------------------------------------------------------------\n";
 print "Saved session files:\n";
 foreach my $session ( keys %sessions )
{
    my $filename = "session-" . $session . ".out";
    if($sessions{$session} > 0 ){
        print "   " . $filename . "   Count = " . $sessions{$session} . "\n";
        open (CALLFILE, "+>" . $filename);
        print CALLFILE "$sessionbuffers{$session} \n";
        close (CALLFILE);    
                            
    } 
    #else {
        #print "Deleting   " . $filename . "\n";
        #unlink $filename;
        
    #}
  
}
 print "\n\n--------------------------------------------------------------------------\n";
 print OUTFILE "\n\n--------------------------------------------------------------------------\n";
 print "$filecount files parsed\n";
 print OUTFILE "$filecount parsed\n";
 print "$pulltotal messages pulled\n";
 print OUTFILE "$pulltotal messages pulled\n";
 print "OUTFILE is appmanagerExtract.out\n";

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




