#!/usr/bin/perl

use strict;

use POSIX qw(strftime);

my $header;
my $chunk;

if (scalar @ARGV != 1) {
	print STDERR "Usage: $0 filename\n";
	exit 1;
}

open F, "<$ARGV[0]" or die "Cannot open $ARGV[0]: $!";
read F, $header, 12;

my ($riff, $filelen, $wave) = unpack('A4VA4', $header);

printf STDERR "%s - %s (%d bytes)\n", $riff, $wave, $filelen-4;

if ($riff eq 'RIFF' && $wave eq 'WAVE') {
	# it's a wave!  let's read the chunks
	while (!eof(F)) {
		read F, $header, 8;
		if ($header) {
			my ($type, $len) = unpack('A4V', $header);

			printf STDERR "   %s (%d)\n", $type, $len;

			if ($type eq 'bext') {
				read F, $chunk, $len;
				# further parse the bwav chunk
				my ($description, $originator, $originator_reference,
						$origination_date, $origination_time, $time_ref_low,
						$time_ref_high, $version, $smpte_umid, $res, $history)=
					unpack('A256 A32 A32 A10 A8 V V v a64 A190 A*', $chunk);
				my @smpte_umid=unpack('C*', $smpte_umid);
				printf STDERR 
"         Description:       %s
         Originator:        %s
         Originator Ref:    %s
         Origination Date:  %s
         Origination Time:  %s
         Time Ref Low:      %d
         Time Ref High:     %d
         BWF Version:       %d
         SMPTE UMID Bytes:  %s
         Coding History:    %s\n",
				$description, $originator, $originator_reference,
				$origination_date, $origination_time,
				$time_ref_low, $time_ref_high,
				$version,
				join(' ', @smpte_umid), $history;

			} elsif ($type eq 'fmt') {
				read F, $chunk, $len;
				my ($format_tag, $channels, $samples_per_sec,
						$avg_bytes_per_sec, $block_align, $bits_per_sample) =
					unpack('v v V V v v', $chunk);
				printf STDERR
"         Format Tag:        %d (%s)
         Channels:          %d
         Samples per sec:   %d
         Avg bytes per sec: %d
         Block align:       %d
         Bits per sample:   %d\n",
				$format_tag, &FormatTagTranslate($format_tag), $channels, $samples_per_sec,
				$avg_bytes_per_sec, $block_align, $bits_per_sample;
			} elsif ($type eq 'fact') {
				read F, $chunk, $len;
				my ($samples) = unpack('V', $chunk);
				printf STDERR "         Samples:           %d\n", $samples;
			} else {
				seek F, $len, 1;
			}
		}
	}
}

close F;

sub min {
	my ($a,$b)=@_;
	if ($a<$b) { return $a; } else { return $b; }
}

sub FormatTagTranslate {

my $ft= sprintf("0x%x",@_);


if($ft eq "0x1"){return "Microsoft PCM";}
elsif($ft eq "0x2"){return "Microsoft ADPCM";}
elsif($ft eq "0x3"){return "Microsoft IEEE float";}
elsif($ft eq "0x4"){return "Compaq VSELP";}
elsif($ft eq "0x5"){return "IBM CVSD";}
elsif($ft eq "0x6"){return "Microsoft a-Law";}
elsif($ft  eq  "0x7"){return "Microsoft u-Law";}
elsif($ft eq "0x8"){return "Microsoft DTS";}
elsif($ft eq "0x9"){return "DRM";}
elsif($ft eq "0xa"){return "WMA 9 Speech";}
elsif($ft eq "0xb"){return "Microsoft Windows Media RT Voice";}
elsif($ft eq "0x10"){return "OKI-ADPCM";}
elsif($ft eq "0x11"){return "Intel IMA/DVI-ADPCM";}
elsif($ft eq "0x12"){return "Videologic Mediaspace ADPCM";}
elsif($ft eq "0x13"){return "Sierra ADPCM";}
elsif($ft eq "0x14"){return "Antex G.723 ADPCM";}
elsif($ft eq "0x15"){return "DSP Solutions DIGISTD";}
elsif($ft eq "0x16"){return "DSP Solutions DIGIFIX";}
elsif($ft eq "0x17"){return "Dialoic OKI ADPCM";}
elsif($ft eq "0x18"){return "Media Vision ADPCM";}
elsif($ft eq "0x19"){return "HP CU";}
elsif($ft eq "0x1a"){return "HP Dynamic Voice";}
elsif($ft eq "0x20"){return "Yamaha ADPCM";}
elsif($ft eq "0x21"){return "SONARC Speech Compression";}
elsif($ft eq "0x22"){return "DSP Group True Speech";}
elsif($ft eq "0x23"){return "Echo Speech Corp.";}
elsif($ft eq "0x24"){return "Virtual Music Audiofile AF36";}
elsif($ft eq "0x25"){return "Audio Processing Tech.";}
elsif($ft eq "0x26"){return "Virtual Music Audiofile AF10";}
elsif($ft eq "0x27"){return "Aculab Prosody 1612";}
elsif($ft eq "0x28"){return "Merging Tech. LRC";}
elsif($ft eq "0x30"){return "Dolby AC2";}
elsif($ft eq "0x31"){return "Microsoft GSM610";}
elsif($ft eq "0x32"){return "MSN Audio";}
elsif($ft eq "0x33"){return "Antex ADPCME";}
elsif($ft eq "0x34"){return "Control Resources VQLPC";}
elsif($ft eq "0x35"){return "DSP Solutions DIGIREAL";}
elsif($ft eq "0x36"){return "DSP Solutions DIGIADPCM";}
elsif($ft eq "0x37"){return "Control Resources CR10";}
elsif($ft eq "0x38"){return "Natural MicroSystems VBX ADPCM";}
elsif($ft eq "0x39"){return "Crystal Semiconductor IMA ADPCM";}
elsif($ft eq "0x3a"){return "Echo Speech ECHOSC3";}
elsif($ft eq "0x3b"){return "Rockwell ADPCM";}
elsif($ft eq "0x3c"){return "Rockwell DIGITALK";}
elsif($ft eq "0x3d"){return "Xebec Multimedia";}
elsif($ft eq "0x40"){return "Antex G.721 ADPCM";}
elsif($ft eq "0x41"){return "Antex G.728 CELP";}
elsif($ft eq "0x42"){return "Microsoft MSG723";}
elsif($ft eq "0x43"){return "IBM AVC ADPCM";}
elsif($ft eq "0x45"){return "ITU-T G.726";}
elsif($ft eq "0x50"){return "Microsoft MPEG";}
elsif($ft eq "0x51"){return "RT23 or PAC";}
elsif($ft eq "0x52"){return "InSoft RT24";}
elsif($ft eq "0x53"){return "InSoft PAC";}
elsif($ft eq "0x55"){return "MP3";}
elsif($ft eq "0x59"){return "Cirrus";}
elsif($ft eq "0x60"){return "Cirrus Logic";}
elsif($ft eq "0x61"){return "ESS Tech. PCM";}
elsif($ft eq "0x62"){return "Voxware Inc.";}
elsif($ft eq "0x63"){return "Canopus ATRAC";}
elsif($ft eq "0x64"){return "APICOM G.726 ADPCM";}
elsif($ft eq "0x65"){return "APICOM G.722 ADPCM";}
elsif($ft eq "0x66"){return "Microsoft DSAT";}
elsif($ft eq "0x67"){return "Micorsoft DSAT DISPLAY";}
elsif($ft eq "0x69"){return "Voxware Byte Aligned";}
elsif($ft eq "0x70"){return "Voxware AC8";}
elsif($ft eq "0x71"){return "Voxware AC10";}
elsif($ft eq "0x72"){return "Voxware AC16";}
elsif($ft eq "0x73"){return "Voxware AC20";}
elsif($ft eq "0x74"){return "Voxware MetaVoice";}
elsif($ft eq "0x75"){return "Voxware MetaSound";}
elsif($ft eq "0x76"){return "Voxware RT29HW";}
elsif($ft eq "0x77"){return "Voxware VR12";}
elsif($ft eq "0x78"){return "Voxware VR18";}
elsif($ft eq "0x79"){return "Voxware TQ40";}
elsif($ft eq "0x7a"){return "Voxware SC3";}
elsif($ft eq "0x7b"){return "Voxware SC3";}
elsif($ft eq "0x80"){return "Soundsoft";}
elsif($ft eq "0x81"){return "Voxware TQ60";}
elsif($ft eq "0x82"){return "Microsoft MSRT24";}
elsif($ft eq "0x83"){return "AT&T G.729A";}
elsif($ft eq "0x84"){return "Motion Pixels MVI MV12";}
elsif($ft eq "0x85"){return "DataFusion G.726";}
elsif($ft eq "0x86"){return "DataFusion GSM610";}
elsif($ft eq "0x88"){return "Iterated Systems Audio";}
elsif($ft eq "0x89"){return "Onlive";}
elsif($ft eq "0x8a"){return "Multitude, Inc. FT SX20";}
elsif($ft eq "0x8b"){return "Infocom ITS A/S G.721 ADPCM";}
elsif($ft eq "0x8c"){return "Convedia G729";}
elsif($ft eq "0x8d"){return "Not specified congruency, Inc.";}
elsif($ft eq "0x91"){return "Siemens SBC24";}
elsif($ft eq "0x92"){return "Sonic Foundry Dolby AC3 APDIF";}
elsif($ft eq "0x93"){return "MediaSonic G.723";}
elsif($ft eq "0x94"){return "Aculab Prosody 8kbps";}
elsif($ft eq "0x97"){return "ZyXEL ADPCM";}
elsif($ft eq "0x98"){return "Philips LPCBB";}
elsif($ft eq "0x99"){return "Studer Professional Audio Packed";}
elsif($ft eq "0xa0"){return "Malden PhonyTalk";}
elsif($ft eq "0xa1"){return "Racal Recorder GSM";}
elsif($ft eq "0xa2"){return "Racal Recorder G720.a";}
elsif($ft eq "0xa3"){return "Racal G723.1";}
elsif($ft eq "0xa4"){return "Racal Tetra ACELP";}
elsif($ft eq "0xb0"){return "NEC AAC NEC Corporation";}
elsif($ft eq "0xff"){return "AAC";}
elsif($ft eq "0x100"){return "Rhetorex ADPCM";}
elsif($ft eq "0x101"){return "IBM u-Law";}
elsif($ft eq "0x102"){return "IBM a-Law";}
elsif($ft eq "0x103"){return "IBM ADPCM";}
elsif($ft eq "0x111"){return "Vivo G.723";}
elsif($ft eq "0x112"){return "Vivo Siren";}
elsif($ft eq "0x120"){return "Philips Speech Processing CELP";}
elsif($ft eq "0x121"){return "Philips Speech Processing GRUNDIG";}
elsif($ft eq "0x123"){return "Digital G.723";}
elsif($ft eq "0x125"){return "Sanyo LD ADPCM";}
elsif($ft eq "0x130"){return "Sipro Lab ACEPLNET";}
elsif($ft eq "0x131"){return "Sipro Lab ACELP4800";}
elsif($ft eq "0x132"){return "Sipro Lab ACELP8V3";}
elsif($ft eq "0x133"){return "Sipro Lab G.729";}
elsif($ft eq "0x134"){return "Sipro Lab G.729A";}
elsif($ft eq "0x135"){return "Sipro Lab Kelvin";}
elsif($ft eq "0x136"){return "VoiceAge AMR";}
elsif($ft eq "0x140"){return "Dictaphone G.726 ADPCM";}
elsif($ft eq "0x150"){return "Qualcomm PureVoice";}
elsif($ft eq "0x151"){return "Qualcomm HalfRate";}
elsif($ft eq "0x155"){return "Ring Zero Systems TUBGSM";}
elsif($ft eq "0x160"){return "Microsoft Audio1";}
elsif($ft eq "0x161"){return "Windows Media Audio V2 V7 V8 V9 / DivX audio (WMA) / Alex AC3 Audio";}
elsif($ft eq "0x162"){return "Windows Media Audio Professional V9";}
elsif($ft eq "0x163"){return "Windows Media Audio Lossless V9";}
elsif($ft eq "0x164"){return "WMA Pro over S/PDIF";}
elsif($ft eq "0x170"){return "UNISYS NAP ADPCM";}
elsif($ft eq "0x171"){return "UNISYS NAP ULAW";}
elsif($ft eq "0x172"){return "UNISYS NAP ALAW";}
elsif($ft eq "0x173"){return "UNISYS NAP 16K";}
elsif($ft eq "0x174"){return "MM SYCOM ACM SYC008 SyCom Technologies";}
elsif($ft eq "0x175"){return "MM SYCOM ACM SYC701 G726L SyCom Technologies";}
elsif($ft eq "0x176"){return "MM SYCOM ACM SYC701 CELP54 SyCom Technologies";}
elsif($ft eq "0x177"){return "MM SYCOM ACM SYC701 CELP68 SyCom Technologies";}
elsif($ft eq "0x178"){return "Knowledge Adventure ADPCM";}
elsif($ft eq "0x180"){return "Fraunhofer IIS MPEG2AAC";}
elsif($ft eq "0x190"){return "Digital Theater Systems DTS DS";}
elsif($ft eq "0x200"){return "Creative Labs ADPCM";}
elsif($ft eq "0x202"){return "Creative Labs FASTSPEECH8";}
elsif($ft eq "0x203"){return "Creative Labs FASTSPEECH10";}
elsif($ft eq "0x210"){return "UHER ADPCM";}
elsif($ft eq "0x215"){return "Ulead DV ACM";}
elsif($ft eq "0x216"){return "Ulead DV ACM";}
elsif($ft eq "0x220"){return "Quarterdeck Corp.";}
elsif($ft eq "0x230"){return "I-Link VC";}
elsif($ft eq "0x240"){return "Aureal Semiconductor Raw Sport";}
elsif($ft eq "0x241"){return "ESST AC3";}
elsif($ft eq "0x250"){return "Interactive Products HSX";}
elsif($ft eq "0x251"){return "Interactive Products RPELP";}
elsif($ft eq "0x260"){return "Consistent CS2";}
elsif($ft eq "0x270"){return "Sony SCX";}
elsif($ft eq "0x271"){return "Sony SCY";}
elsif($ft eq "0x272"){return "Sony ATRAC3";}
elsif($ft eq "0x273"){return "Sony SPC";}
elsif($ft eq "0x280"){return "TELUM Telum Inc.";}
elsif($ft eq "0x281"){return "TELUMIA Telum Inc.";}
elsif($ft eq "0x285"){return "Norcom Voice Systems ADPCM";}
elsif($ft eq "0x300"){return "Fujitsu FM TOWNS SND";}
elsif($ft eq "0x301"){return "Fujitsu (not specified)";}
elsif($ft eq "0x302"){return "Fujitsu (not specified)";}
elsif($ft eq "0x303"){return "Fujitsu (not specified)";}
elsif($ft eq "0x304"){return "Fujitsu (not specified)";}
elsif($ft eq "0x305"){return "Fujitsu (not specified)";}
elsif($ft eq "0x306"){return "Fujitsu (not specified)";}
elsif($ft eq "0x307"){return "Fujitsu (not specified)";}
elsif($ft eq "0x308"){return "Fujitsu (not specified)";}
elsif($ft eq "0x350"){return "Micronas Semiconductors, Inc. Development";}
elsif($ft eq "0x351"){return "Micronas Semiconductors, Inc. CELP833";}
elsif($ft eq "0x400"){return "Brooktree Digital";}
elsif($ft eq "0x401"){return "Intel Music Coder (IMC)";}
elsif($ft eq "0x402"){return "Ligos Indeo Audio";}
elsif($ft eq "0x450"){return "QDesign Music";}
elsif($ft eq "0x500"){return "On2 VP7 On2 Technologies";}
elsif($ft eq "0x501"){return "On2 VP6 On2 Technologies";}
elsif($ft eq "0x680"){return "AT&T VME VMPCM";}
elsif($ft eq "0x681"){return "AT&T TCP";}
elsif($ft eq "0x700"){return "YMPEG Alpha (dummy for MPEG-2 compressor)";}
elsif($ft eq "0x8ae"){return "ClearJump LiteWave (lossless)";}
elsif($ft eq "0x1000"){return "Olivetti GSM";}
elsif($ft eq "0x1001"){return "Olivetti ADPCM";}
elsif($ft eq "0x1002"){return "Olivetti CELP";}
elsif($ft eq "0x1003"){return "Olivetti SBC";}
elsif($ft eq "0x1004"){return "Olivetti OPR";}
elsif($ft eq "0x1100"){return "Lernout & Hauspie";}
elsif($ft eq "0x1101"){return "Lernout & Hauspie CELP codec";}
elsif($ft eq "0x1102"){return "Lernout & Hauspie SBC codec";}
elsif($ft eq "0x1103"){return "Lernout & Hauspie SBC codec";}
elsif($ft eq "0x1104"){return "Lernout & Hauspie SBC codec";}
elsif($ft eq "0x1400"){return "Norris Comm. Inc.";}
elsif($ft eq "0x1401"){return "ISIAudio";}
elsif($ft eq "0x1500"){return "AT&T Soundspace Music Compression";}
elsif($ft eq "0x181c"){return "VoxWare RT24 speech codec";}
elsif($ft eq "0x181e"){return "Lucent elemedia AX24000P Music codec";}
elsif($ft eq "0x1971"){return "Sonic Foundry LOSSLESS";}
elsif($ft eq "0x1979"){return "Innings Telecom Inc. ADPCM";}
elsif($ft eq "0x1c07"){return "Lucent SX8300P speech codec";}
elsif($ft eq "0x1c0c"){return "Lucent SX5363S G.723 compliant codec";}
elsif($ft eq "0x1f03"){return "CUseeMe DigiTalk (ex-Rocwell)";}
elsif($ft eq "0x1fc4"){return "NCT Soft ALF2CD ACM";}
elsif($ft eq "0x2000"){return "FAST Multimedia DVM";}
elsif($ft eq "0x2001"){return "Dolby DTS (Digital Theater System)";}
elsif($ft eq "0x2002"){return "RealAudio 1 / 2 14.4";}
elsif($ft eq "0x2003"){return "RealAudio 1 / 2 28.8";}
elsif($ft eq "0x2004"){return "RealAudio G2 / 8 Cook (low bitrate)";}
elsif($ft eq "0x2005"){return "RealAudio 3 / 4 / 5 Music (DNET)";}
elsif($ft eq "0x2006"){return "RealAudio 10 AAC (RAAC)";}
elsif($ft eq "0x2007"){return "RealAudio 10 AAC+ (RACP)";}
elsif($ft eq "0x2500"){return "Reserved range to 0x2600 Microsoft";}
elsif($ft eq "0x3313"){return "makeAVIS (ffvfw fake AVI sound from AviSynth scripts)";}
elsif($ft eq "0x4143"){return "Divio MPEG-4 AAC audio";}
elsif($ft eq "0x4201"){return "Nokia adaptive multirate";}
elsif($ft eq "0x4243"){return "Divio G726 Divio, Inc.";}
elsif($ft eq "0x434c"){return "LEAD Speech";}
elsif($ft eq "0x564c"){return "LEAD Vorbis";}
elsif($ft eq "0x5756"){return "WavPack Audio";}
elsif($ft eq "0x674f"){return "Ogg Vorbis (mode 1)";}
elsif($ft eq "0x6750"){return "Ogg Vorbis (mode 2)";}
elsif($ft eq "0x6751"){return "Ogg Vorbis (mode 3)";}
elsif($ft eq "0x676f"){return "Ogg Vorbis (mode 1+)";}
elsif($ft eq "0x6770"){return "Ogg Vorbis (mode 2+)";}
elsif($ft eq "0x6771"){return "Ogg Vorbis (mode 3+)";}
elsif($ft eq "0x7000"){return "3COM NBX 3Com Corporation";}
elsif($ft eq "0x706d"){return "FAAD AAC";}
elsif($ft eq "0x7a21"){return "GSM-AMR (CBR, no SID)";}
elsif($ft eq "0x7a22"){return "GSM-AMR (VBR, including SID)";}
elsif($ft eq "0xa100"){return "Comverse Infosys Ltd. G723 1";}
elsif($ft eq "0xa101"){return "Comverse Infosys Ltd. AVQSBC";}
elsif($ft eq "0xa102"){return "Comverse Infosys Ltd. OLDSBC";}
elsif($ft eq "0xa103"){return "Symbol Technologies G729A";}
elsif($ft eq "0xa104"){return "VoiceAge AMR WB VoiceAge Corporation";}
elsif($ft eq "0xa105"){return "Ingenient Technologies Inc. G726";}
elsif($ft eq "0xa106"){return "ISO/MPEG-4 advanced audio Coding";}
elsif($ft eq "0xa107"){return "Encore Software Ltd G726";}
elsif($ft eq "0xa109"){return "Speex ACM Codec xiph.org";}
elsif($ft eq "0xdfac"){return "DebugMode SonicFoundry Vegas FrameServer ACM Codec";}
elsif($ft eq "0xe708"){return "Unknown -";}
elsif($ft eq "0xf1ac"){return "Free Lossless Audio Codec FLAC";}
elsif($ft eq "0xfffe"){return "Extensible";}
elsif($ft eq "0xffff"){return "Development";}

return "Unknown";
}