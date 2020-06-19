#!/usr/bin/perl

open (OUTFILE, ">Resources.csv");

print OUTFILE "Timestamp";
print "------------------------------------------------------------\n";


my @SEARCHSTR = @ARGV;

print "Search strings are: \n";
foreach my $a (@SEARCHSTR) {
	print "$a\n";
    print OUTFILE",";
    print OUTFILE "$a"; 
}
print OUTFILE "\n";


@files = <xmserver-*.log>;

$timestampformat = "^.*?(..:..:.........).*? ";
my $blockstart = "^.*?(..:..:.........).*?DEBUG.*?Resource usage.";

foreach $file (@files) {
  print "parsing" . $file . "\n";
  
  $linesparsed = 0 ;
  $blocksparsed = 0;
  open (MYFILE, $file);
  $lastts="";
  $inblock=0;
  $block="";
  
   while (<MYFILE>) {
         $linesparsed++;
              
         #check for the timestamp to see if start of block and save it
         if(/$timestampformat/){
            #if you are in meter block and hit another timestamp you are done with that section
            if($inblock == 1){
                $blocksparsed++;
                
                my $csvline=parse_block($block,\@SEARCHSTR);
                print OUTFILE $lastts . $csvline . "\n";
             #   print $lastts . $csvline . "\n";
                $block="";
                $inblock=0;
            }
            $lastts=$1;           
        }
        #next we check for the tag to confirm that file was read and start saving block
        if(/$blockstart/){
            $block=$lastts . "\n";
            $inblock=1;
            
        }else{
            #if you are still in block just keep appending lings to block for processing
            if ($inblock == 1){
                $block=$block . $_ ;
            }
        }
   }
        
               
 print "\n$linesparsed lines parsed, $blocksparsed blocks parsed\n";
 
 close (MYFILE);
 }
 
 close (OUTFILE);


################# SUBS #################
sub parse_block{
    my ($block) = @_[0];
    my @SEARCHSTR = @{$_[1]};
    my $retstr="";
   
    #print $block . "\n";           
    foreach $searchstr (@SEARCHSTR) {
       if( $block=~ /\n.*$searchstr.*? active. (\d*),/ ) {
            #print "found $searchstr = $1\n";
            $retstr=$retstr . "," . $1;

        }
    }

    return $retstr
}




