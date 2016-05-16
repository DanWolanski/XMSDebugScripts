#!/usr/bin/perl

open (OUTFILE, ">appmanagerExtract.out");

print OUTFILE "------------------------------------------------------------\n";

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
            
            if(@ARGV < 1){
                $pullcount++;
                if($pullcount==1){
                    print OUTFILE "parsing" . $file . "\n";
                }
                $block=format_block($block);
                print OUTFILE $block . "\n";
                
            }else{
                foreach $searchstr (@ARGV) {
                if (index($block, $searchstr) != -1) {
                    $pullcount++;
                    if($pullcount==1){
                        print OUTFILE "parsing" . $file . "\n";
                    }
                    $block=format_block($block);
                    print OUTFILE "$block" . "\n";
                 
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
        
        
 print "$linesparsed lines parsed\n";
 #print OUTFILE "$linesparsed lines parsed\n";
 print "$pullcount messages pulled\n\n";
 #print OUTFILE "$pullcount messages pulled\n\n";
 $pulltotal += $pullcount;
 
 close (MYFILE);
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

    $block =~ s/\\r\\n/\n      /g;
    $block =~ s/\\t/    /g;
    $block =~ s/></>\n       </g;
    $block =~ s/\\\//\\/g;
    $block =~ s/\\\"/\"/g;
    
    return $block
}




