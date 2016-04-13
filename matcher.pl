#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

$incstr = "^.*Start.*";
$decstr = "^.*Stop.*";
$endstr = "^.*End.*";
open (OUTFILE, ">matched.out");

print OUTFILE "Matcher on $ARGV[0] for \n     Start=$incstr \n     Stop=$decstr \n     End=$endstr \n ";
print "FileMatch for \n     Start=$incstr \n     Stop=$decstr \n     End=$endstr \n";
print OUTFILE "------------------------------------------------------------\n";

$count = 0;

open (MYFILE, $ARGV[0]);
 while (<MYFILE>) {
        if(/$endstr/){
                print OUTFILE "E($count) - $_";
                last;
        }
        elsif(/$incstr/){
                $count++;
                print OUTFILE "+($count)$_";

        }
        elsif(/$decstr/){
                $count--;
                print OUTFILE "-($count)$_";
        }
        else{
        #don't care about this one
        }

 }
 print "\n\nFinal count = $count\n\n";
 print OUTFILE "\n\nFinal count = $count\n\n";
 close (MYFILE);
 close (OUTFILE);

