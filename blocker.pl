#!/usr/bin/perl
#./blocker.pl *.log | grep a1dbe7388eea4980b76b2ee45cdc29a9 | sort | sed 's/\\n/\n/g'  
my $inblock=false;
my $block="";
$timestampformat = "^(20..-..-.. ..:..:..\.......)";
my $lastts = "";

#@files = <appmanager*.log>;
my @files = @ARGV;


foreach $file (@files) {
  my $currentfile=$file;
  open (MYFILE, $file);
     while (<MYFILE>) {
		 if(/$timestampformat.*/){
			if($block.length > 1){
				DumpBlock($block);
			}
			$block=$_;
		 } else {
			$block=$block.$_;
		 }
	 }
	 #end of file so dump block as we don't span files in our logs
	 DumpBlock($block);
	 $block="";
}


################# SUBS #################
sub DumpBlock {
	my ($block) = @_;
	$block =~ s/\n/\\n/g;
	$block =~ s/\s+/ /g;
	
	print "$block\n"

}
			
