#!/usr/bin/perl

open (OUTFILE, ">TopOutput.csv");

print OUTFILE "Timestamp,CPU-total Used,MEM-Total used,MEM-Total free, MEM-Total Buffers, SWAP-Used";
print "------------------------------------------------------------\n";



my @SEARCHSTR = @ARGV;

print "Search strings are: \n";
foreach my $a (@SEARCHSTR) {
	print "$a\n";
    print OUTFILE",";
    print OUTFILE "$a-VIRT,";
		print OUTFILE "$a-RES,";
		print OUTFILE "$a-SHR,";
		print OUTFILE "$a-CPU,";
		print OUTFILE "$a-MEM";
}
print OUTFILE "\n";

@files = <top-*.txt>;

$timestampformat = "..:..:..";
my $blockstart = "^top - ($timestampformat) up.*";
my $liststart = "^  PID USER.*COMMAND  ";
#todo chart out the CPU, MEM, Swap and load average
foreach $file (@files) {
  print "parsing " . $file . "\n";

  $linesparsed = 0 ;
  $blocksparsed = 0;
  open (MYFILE, $file);
  $lastts="";
  $inblock=0;
  $block="";

   while (<MYFILE>) {
         $linesparsed++;
				 $lastts=$1;
         #check for the start of the top line
         if(/$blockstart/){
            #if you are in meter block and hit another timestamp you are done with that section
            if($inblock == 1){
                $blocksparsed++;

                my $csvline=parse_block($block,\@SEARCHSTR);
                print OUTFILE $lastts . $csvline . "\n";
    #            print $lastts . $csvline . "\n";
                $block="";
                $inblock=0;
            }
        }
        #next we check for the tag to confirm that file was read and start saving block
        if(/$blockstart/){
            $block=$lastts . "\n";
            $inblock=1;

        }else{
            #if you are still in block just keep appending lings to block for processing
            if ($inblock == 1){
                $block=$block . $_  . "\n";
            }
        }
   }

#running one last time for end of file
if($inblock == 1){
                $blocksparsed++;

                my $csvline=parse_block($block,\@SEARCHSTR);
                print OUTFILE $lastts . $csvline . "\n";
    #            print $lastts . $csvline . "\n";
                $block="";
                $inblock=0;
            }
 print "\n$linesparsed lines parsed, $blocksparsed blocks parsed\n";

 close (MYFILE);
 }

 close (OUTFILE);


################# SUBS #################
sub parse_block{
    my ($block) = @_[0];
    my @SEARCHSTR = @{$_[1]};
    my $retstr=",";

    #print $block . "\n";
    if( $block=~ /\nCpu.s.: (.*?)us,.*?\n/ ) {
				 $retstr=$retstr . $1 . ",";
			 }
			 if( $block=~ /\nMem:.*?,(.*?) used, (.*?) free, (.*?) buffers.*?\n/ ) {
				 $retstr=$retstr . $1 . ",";
				 $retstr=$retstr . $2 . ",";
				 $retstr=$retstr . $3 . ",";
			 }
			 if( $block=~ /\nSwap: .*?, (.*?) used,.*?\n/ ) {
				 $retstr=$retstr . $1 . ",";
			 }

    foreach $searchstr (@SEARCHSTR) {
			#PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
			#31997 root      RT   0 10.1g 4.0g 129m S 23.7 51.8   3286:30 ssp_x86Linux_bo
			 
			#                  PID        USER     PR    NI    VIRT    RES   SHR    S    CPU   MEM   TIME COMMAND
			 if( $block=~ /\n(.*?$searchstr.*?)\n/ ) {
				    my $line = $1;
						#print $line . "\n";
						my $virt = substr $line , 23 , 5;
						my $res = substr $line , 29 , 4;
						my $shr = substr $line , 34 , 4;
						my $cpu = substr $line , 41 , 4;
						my $mem = substr $line , 46 , 4;


            $retstr=$retstr . $virt . "," . $res . "," . $shr . "," . $cpu . "," . $mem . "," ;
						#print "TIMESTAMP,"$retstr . "\n";
        }
    }

    $retstr =~ s/k/000/g;
    $retstr =~ s/m/000000/g;
    $retstr =~ s/g/000000000/g;
    
    return $retstr
}
