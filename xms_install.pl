#!/usr/bin/perl -w

######################################################################
#
# Dialogic(r) PowerMedia eXtended Media Server installation
#
# Copyright (C) 2001-2013 Dialogic Corporation.  All Rights Reserved.
#
# All names, products, and services mentioned herein are the
# trademarks or registered trademarks of their respective
# organizations and are the sole property of their respective
# owners.
#
######################################################################

use 5.10.1;
use strict;
use feature 'state';

use Getopt::Long;
use File::Copy;
use File::Temp;
use File::Basename;
use File::Path qw(remove_tree make_path);
use Class::Struct;
use DirHandle;
use Cwd qw(abs_path cwd);

#*********************************************
#	Globals
#*********************************************

my $Xms_File_Version          = '';
my $Xms_Installed_Version     = '';
my $Xms_HMP_Installed_Version = '';

use constant { XIS_NOT_INSTALLED => 0,
               XIS_PARTIAL       => 1,
               XIS_INSTALLED     => 2
};

my $Xms_Install_Status = XIS_NOT_INSTALLED;

my $Xms_Pkg_Dir = './xms_distribution';

# Operating modes
use constant { IM_NONE    => 0,
               IM_INSTALL => 1,
               IM_UPDATE  => 2,
               IM_REMOVE  => 4,
               IM_TEST    => 8,
};

my $Xms_Install_Mode = IM_INSTALL;

use constant { OSCA_CHECK     => 0,
               OSCA_CONFIGURE => 1,
};

# Linux Distributions and minimum versions supported by this XMS release
my %Distros_Supported = (

    # distro name ( in /etc/system-release) => minimum version
    'Red Hat' => '6.2',
    'CentOS'  => '6.2',
    'Oracle'  => '6.2',

    #SuSE   => '11.2',
);

my $Distro_ID = "";

####################################################
# Package name lists
# format must be just the package name (from rpm -qi -p pkg.rpm) or
# name.arch if the required arch is not x86_64
###################################################

# Required Packages from the standard Centos and RHEL distribution
my @Pkgs_Distro_Required = qw(
  bzip2 bzip2-libs.i686 cairo cairo.i686 expect fontconfig.i686 freetype.i686 ghostscript.i686 glib2 gtk2 gtk2.i686
  httpd mod_perl perl-BSD-Resource jasper-libs.i686 lcms-libs.i686 libgomp.i686 libICE.i686  libpng.i686 librsvg2.i686
  libstdc++ libtool libuuid.i686 libxml2 libX11.i686 libSM.i686 libtiff.i686 libtool-ltdl.i686
  libwmf-lite.i686 libXt.i686 mod_ssl ncurses ncurses-libs.i686 ntp openssl openssl.i686 pango pcre pcre.i686
  php-cli php-common php-ldap php php-pdo redhat-lsb sox telnet uuid zlib.i686 tcpdump
  libidn.i686 cyrus-sasl-lib.i686 openldap.i686 nss nss.i686 nss-util.i686 nss-softokn.i686 db4.i686 readline.i686  sqlite.i686 libssh2.i686
  libcurl.i686 nspr.i686 nfs-utils  nfs-utils-lib libtirpc libgssglue libevent rpcbind
  libraw1394  libdc1394 SDL speex libcdio  pulseaudio-libs net-snmp net-snmp-libs net-snmp-libs.i686
);

# Prerequisite packages requiring special processing
my @Pkgs_Distro_Special = qw( nss-sysinit.i686 libjpeg-turbo.i686 libjpeg-turbo libjpeg.i686 libjpeg);

# Incompatible (conflicting) OS packages that must be removed before installling XMS.
my @Pkgs_Distro_Incompatible = qw(ImageMagick.x86_64 );

# Supplied third party packages that are not available in all supported distributions
my @Pkgs_Support = qw(
  zeromq.i386 xerces-c.i686 fcgi.i686  dojo.noarch lighttpd lighttpd-fastcgi spawn-fcgi js.i686
  libwebsockets.i386 ImageMagick.i686 ImageMagick-c++.i686 ilbc x264 x264-libs ffmpeg-libs ffmpeg opus
  lame-libs xvidcore svgalib libass schroedinger orc libv4l  librtmp openal-soft libva1 enca celt
);

# Core XMS components
my @Pkgs_Xms_Components = qw(appmanager.i386 broker.i386 libxms.i386 restful.i386 xmserver.i386 xmsadmin.noarch nodecontroller.i386
  vxml.i386 httpclient.i386 netann.i386 libmrcp.i386 mrcpclient.i386 hlsserver.i386 msml.i386 rtcweb.i386 phrserver.noarch snmpsubagent.i386
  perfmanager-libs.i386 perfmanager.i386  );

# Hmp media packages
my @Pkgs_Hmp_Media     = qw(lsb-dialogic-hmp41-msp.noarch );
my @Pkgs_Hmp_Sybsystem = qw(lsb-dialogic-hmp41-com.i386 lsb-dialogic-hmp41-dmdev.i386 lsb-dialogic-hmp41-docs.noarch lsb-dialogic-hmp41-hmp.i386
  lsb-dialogic-hmp41-lic.i386 lsb-dialogic-hmp41-x64com lsb-dialogic-hmp41-x64hmp);

#
# package management
#

my %Pkg_Groups;

struct Pkg => { name         => '$',
                filename     => '$',
                path         => '$',
                file_version => '$',
                file_release => '$',
                inst_version => '$',
                inst_release => '$',
                arch         => '$',
                is_installed => '$',
                file_size    => '$',
                inst_size    => '$'
};

struct PkgGrp => { name          => '$',
                   dir           => '$',
                   no_post_upg   => '$',
                   no_check_ver  => '$',
                   file_required => '$',
                   group         => '@'
};

struct Srv => { name        => '$',
                description => '$'
};

struct Hmp => { path            => '$',
                dist_version    => '$',
                inst_version    => '$',
                cli_telnet_port => '$',
                rtp_address     => '$',
                _tar_dir        => '$',
                _media_pkgs     => 'PkgGrp',
                _hmp_pkgs       => 'PkgGrp'
};

#
# Global Errno style return codes
#

use constant {
    E_OK                    => 0,
    E_GEN_FAILED            => 1,     # general error
    E_GEN_COMMAND_LINE      => 2,     # command line parameter error
    E_GEN_DIST_CORRUPTED    => 3,     # The distribution is corrupted (missing file(s) etc.)
    E_GEN_XMS_CORRUPTED     => 4,     # The currently installed XMS is corrupted (not fully installed , etc.)
    E_GEN_PREREQUISITES     => 5,     # Prereq OS pkgs are missing and can't be auto installed (likely Yum not setup)
    E_GEN_BAD_ENV           => 6,     # Not root or not x64 arch or OS distribution not supported
    E_GEN_DISK_SPACE        => 7,     # Not enough space on the target filesystem for the requested operation
    E_GEN_PREREQ_NOT_COMPAT => 8,     # One or more installed OS packages are incompatible with XMS prerequisites
    E_UPG_NO_DOWNGRADE      => 20,    # Downgrade not allowed
    E_UPG_SAME_VERSION      => 21,    # Upgrade version already installed

};

my $Errno = E_GEN_FAILED;             # Examined when subs return false

#
# log management
#
use constant { LL_DEBUG    => 6,
               LL_VVERBOSE => 5,
               LL_VERBOSE  => 4,
               LL_INFO     => 3,
               LL_WARNING  => 2,
               LL_ERROR    => 1,
               LL_NONE     => 0
};

my $Xms_Log_File  = 'xms_install.log';
my $Xms_Log_Level = LL_INFO;

#
# Firewall ports
#
my $Xms_Fw_Ports_T = 'tcp: 22, 80, 81, 443, 1080, 5060, 10443, 15001';
my $Xms_Fw_Ports_U = 'udp: 5060, 49152-53152, 57344-57840';

#
# service managment
#
my @OS_Service_Names = qw (ntpd httpd lighttpd snmpd snmptrapd);
my %OS_Services;

my %XMS_Service_Names = ( 'dlgclockdaemon'  => 'HMP subsystem',
                          'media_server'    => 'MSML Media Server (legacy)',
                          'nodecontroller'  => 'Node Controller',
                          'broker'          => 'Broker',
                          'xmsrest'         => 'RESTful API',
                          'appmanager'      => 'Application Manager',
                          'xmserver'        => 'XM Server',
                          'httpclient'      => 'HTTP Client',
                          'mrcpclient'      => 'MRCP Client',
                          'netann'          => 'NETANN Service',
                          'vxmlinterpreter' => 'VXML Interpreter',
                          'msmlserver'      => 'MSML Service',
                          'rtcweb'          => 'WebRTC Service',
                          'verification'    => 'System Verification Server',
                          'snmpsubagent'    => 'SNMP subagent'
);
my %XMS_Services;

my $Nodecontroller;
my $Hmp;

#
# command line options
#
my %CmdLnOpt = ( 'install'       => 0,
                 'update'        => 0,
                 'clean-install' => 0,
                 'remove'        => 0,
                 'test'          => 0,
                 'cfg-selinux'   => undef,
                 'cfg-hosts'     => undef,
                 'cfg-firewall'  => undef,
                 'cfg-prereq '   => undef,
                 'cfg-https'     => undef,
                 'yes'           => 0,
                 'help'          => 0,
                 'distdir'       => '',
                 'log'           => 1,
                 'logfile'       => "xms_install.log",
                 'append'        => 0,
                 'bn4k'          => '',
                 'xms-cliport'   => undef,
                 'xms-logdir'    => '',
                 'xms-loglevel'  => '',
                 'xms-rtpaddr'   => '',
                 'xms-bindaddr'  => '',
                 'xms_bindport'  => undef,
                 'verbose'       => LL_INFO,
                 'quiet'         => 0,
);

#
# Miscellaneous
#
my $Conf_File_Backup_Ext = '.bak_xms';

# post install setup paths and files

my $Ssl_Conf_File    = '/etc/httpd/conf.d/ssl.conf';
my $Ssl_Conf_File_Bk = $Ssl_Conf_File . $Conf_File_Backup_Ext;

# console output handle
my $ConFd = *STDOUT;

#********************************************
# Utility subs
#********************************************

sub usage {
    my $help_text = <<END_HELP;
  Usage: $0 [OPTION]...
	
  Mode options:
	
  -i, --install       Install XMS if no previous version exists (default)
  -u, --update        Update XMS without affecting current configuration
  -r, --remove        Remove XMS
  -t, --test          Test system and report status without installing anything			
	
  Platform configuration options (negatable with --no-cfg-....):
	
  --cfg-selinux       Disable selinux (default:ask)
  --cfg-hosts         Configure /etc/hosts file (default:ask)
  --cfg-prereq        Install prerequisite OS packages (default:ask)
  --cfg-https         Backup and replace https settings (default:ask)
  
  Advanced options
  
  --xms-cliport PORT  Use PORT for media processing sybsystem (default:23)
  --xms-logdir DIR    XMS log file directory
  --xms-loglevel LVL  Default XMS log level (ERROR,WARN,NOTICE,INFO,DEBUG - dflt: WARN)
  --xms-rtpaddr ADR   XMS IPv4 RTP address
  --xms-bindaddr ADR  XMS IPv4 bind address
  --xms-bindport PORT XMS bind port  
	
  General options
   
  -y, --yes           Answer yes to all questions	
  -h, --help:         Display this message and exit
  -d, --distdir DIR   Directory where the XMS distribution is located
  -l, --log, --nolog  Log (or not) results to a file  (default:enabled)    
  -f, --logfile FILE  Use FILE as the log filename (default: xms_install.log)
  -a, --append        Append to the log file if it exists (default:off)
  -v, --verbose       Print detailed progress information (-vv very verbose)
  -q, --quiet         Do not write anything to standard output 	
	
END_HELP

    print STDERR $help_text;

}

#
# various system platform checks
#

sub is_distro_supported {
    my %distros = @_;

    my $dist_keys = join( '|', keys(%distros) );

    # check for Red Hat / CentOS / Oracle
    if ( open( my $distfh, "<", "/etc/system-release" ) ) {
        my $line = <$distfh>;
        chomp($line);
        close($distfh);

        $Distro_ID = $line;

        if ( $line =~ /^\s*($dist_keys)\b/ ) {
            my ( $maj, $min ) = split( '\.', $distros{$1} );
            if ( $line =~ /\b($maj\.[$min-9])\b/ ) {
                return 1;
            }
        }
    }
    else {
        print "Could not open /etc/system-release:$! \n";
    }

    return;
}

sub is_distro {
    my $distro = shift;
    $Distro_ID or is_distro_supported();
    return $Distro_ID =~ /$distro/;
}

sub is_selinux_enforcing {
    if ( -x '/usr/sbin/getenforce' ) {
        my $rc = `/usr/sbin/getenforce`;
        return $rc =~ /^Enforcing/;
    }
    else {
        return;
    }
}

sub is_64bit_platform {
    my $arch = `uname -i`;
    return $arch =~ /^x86_64|amd64/;
}

sub is_root {
    return $> == 0;
}

sub is_install_mode {
    my $mode_mask = shift;
    return $Xms_Install_Mode & $mode_mask;
}

sub is_yum_setup {
    my $bin   = `which yum`;
    my @repos = @_;
    state $Yummy = -1;
    chomp($bin);

    if ( $Yummy < 0 ) {
        my $rc = 0;
        if ( -x $bin ) {
            my $cmd = join( ' ', $bin, "repolist enabled", @repos, "2> /dev/null" );
            open( my $outp, "-|", $cmd );
            foreach my $line (<$outp>) {
                if ( $line =~ /^repolist:/ ) {
                    my ( $repo, $numb ) = split( ' ', $line, 2 );
                    chomp($numb);
                    $numb =~ s/,//;
                    $rc += $numb;
                    log_msg( LL_DEBUG, "Yum enabled repolist @repos status: $numb" );
                }
            }
            close($outp);
        }
        $Yummy = $rc;
    }
    return $Yummy;
}

sub is_xms_installed {
    return $Xms_Install_Status == XIS_INSTALLED;
}

sub is_installation_valid {
    return $Xms_Install_Status != XIS_PARTIAL;
}

# get free disk space on root filesystem in MB
# returns -1 on error
sub get_disk_free_space {
    my $rv = -1;
    if ( open( my $output, 'df  -m  /usr  2>/dev/null | ' ) ) {
        while (<$output>) {
            my @fields = split(/\s+/);
            if ( $fields[0] ne 'Filesystem' ) {
                $rv = $fields[3];
            }
        }
        close $output;
    }
    else {
        log_msg( LL_WARNING, "Can't get free disk space: $!" );
    }
    return $rv;
}

#
# Check operating environment for minimum requirements
#
sub verify_env {

    if ( !is_root() ) {
        print "$0: XMS installation requires root priviledges.\n";
        return;
    }

    if ( !is_64bit_platform() ) {
        print "XMS requires a 64-bit platform.\nInstallation aborted.";
        return;
    }

    if ( !is_distro_supported(%Distros_Supported) ) {

        print "Detected unsupported Linux distribution or version", $Distro_ID ? ":\n$Distro_ID\n" : "\n";
        return;
    }

    if ( !( -x '/etc/redhat-lsb/lsb_killproc' and -x '/etc/redhat-lsb/lsb_pidofproc' ) ) {
        print "XMS requires Red Hat LSB (/etc/redhat-lsb/*) utilities\n";
        return;
    }

    return 1;
}

# prompt user and obtain a response
# single character options only
sub ask_user {
    my $prompt  = shift;        # the question
    my $options = lc(shift);    # the choices
    my $default = lc(shift);    # the default choice
    my $response;               # the user's response

    #auto answer if requested
    if ( $CmdLnOpt{'yes'} ) {
        return $default;
    }

    my $disp_opt = join '/', map { $_ eq $default ? uc($_) : $_ } split( //, $options );
    print $ConFd "$prompt [$disp_opt]: ";
    while (1) {

        $response = <STDIN>;
        $response = lc($response);
        chomp($response);
        $response =~ s/^$/$default/;
        last if ( $response =~ /^[$options]$/ );
        print $ConFd "Invalid response. Try again [$disp_opt]: ";
    }
    return $response;
}

#
# Process command line options
#

sub process_options {

    Getopt::Long::Configure("bundling");

    my $rc = GetOptions( \%CmdLnOpt,     'install|i',      'update|u',      'remove|r',       'test|t',         'cfg-selinux!',
                         'cfg-hosts!',   'cfg-firewall!',  'cfg-prereq!',   'cfg-https!',     'xms-cliport=i',  'yes|y',
                         'help|h',       'distdir|d=s',    'log!',          'logfile|f=s',    'append|a',       'bn4k=s',
                         'xms-logdir=s', 'xms-loglevel=s', 'xms-rtpaddr=s', 'xms-bindaddr=s', 'xms-bindport=i', 'xms-optsrv=s',
                         'verbose|v+',   'quiet|q'
    );

    if ( !$rc or $#ARGV != -1 ) {
        foreach (@ARGV) {
            print "Unrecognized Parameter: $_\n";
        }
        print "Try $0 --help for more information.\n";
        return;
    }

    if ( $CmdLnOpt{help} ) {
        usage();
        return;
    }

    # we can only operate in one mode at a time
    if ( ( $CmdLnOpt{'install'} + $CmdLnOpt{'update'} + $CmdLnOpt{'remove'} + $CmdLnOpt{'test'} ) > 1 ) {
        print "Operating mode option must be unique\n";
        print "Try $0 --help for more information.\n";
        return;
    }

    $Xms_Install_Mode = IM_INSTALL;

    if    ( $CmdLnOpt{'update'} )  { $Xms_Install_Mode = IM_UPDATE }
    elsif ( $CmdLnOpt{'install'} ) { $Xms_Install_Mode = IM_INSTALL }
    elsif ( $CmdLnOpt{'remove'} )  { $Xms_Install_Mode = IM_REMOVE }
    elsif ( $CmdLnOpt{'test'} )    { $Xms_Install_Mode = IM_TEST }

    $Xms_Log_File = $CmdLnOpt{logfile};

    if ( $CmdLnOpt{'distdir'} ) { $Xms_Pkg_Dir = $CmdLnOpt{'distdir'}; }

    $Xms_Log_Level = $CmdLnOpt{verbose} <= LL_DEBUG ? $CmdLnOpt{verbose} : LL_DEBUG;

    #force fireweall to manual config for this release
    $CmdLnOpt{'cfg-firewall'} = 0;

    for my $prm ( 'xms-rtpaddr', 'xms-bindaddr' ) {
        if ( $CmdLnOpt{$prm} and $CmdLnOpt{$prm} !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
            print 'Value "', $CmdLnOpt{$prm}, '" invalid for option ', $prm, " (IPv4 address expected)\n";
            return;
        }
    }

    if ( $CmdLnOpt{'xms-rtpaddr'} and $Xms_Install_Mode != IM_INSTALL ) {
        print "xms-rtpaddr option is available in installation mode only\n";
        return;
    }

    for my $prm ( 'xms-cliport', 'xms-bindport' ) {
        if ( defined( $CmdLnOpt{$prm} ) ) {
            if ( $CmdLnOpt{$prm} < 1 or $CmdLnOpt{$prm} > 49151 ) {
                print $prm, " value must be between 1 and 49151\n";
                return;
            }
        }
        else { $CmdLnOpt{$prm} = 0 }
    }

    if ( $CmdLnOpt{'bn4k'} ) {
        if ( !-e $CmdLnOpt{'bn4k'} ) {
            print "BN4K path $CmdLnOpt{'bn4k'} does not exist\n";
            return;
        }
        elsif ( !pst_task_bn4k( $CmdLnOpt{'bn4k'}, 0 ) ) {
            print "BN4K file verification failed\n";
            return;
        }

        @OS_Service_Names = qw (ntpd lighttpd);
        $CmdLnOpt{'cfg-https'} = 0;
    }

    if ( $CmdLnOpt{'xms-logdir'} ) {
        if ( !File::Spec->file_name_is_absolute( $CmdLnOpt{'xms-logdir'} ) ) {
            print "XMS log directory $CmdLnOpt{'xms-logdir'} is not an absolute path\n";
            return;
        }

        $CmdLnOpt{'xms-logdir'} =~ s/\/$//;
        if ( !-e $CmdLnOpt{'xms-logdir'} ) {
            print "XMS log directory $CmdLnOpt{'xms-logdir'} does not exist\n";
            return;
        }

        if ( !-d $CmdLnOpt{'xms-logdir'} ) {
            print "XMS log directory $CmdLnOpt{'xms-logdir'} is not a directory\n";
            return;
        }

    }

    if ( $CmdLnOpt{'xms-loglevel'} and $CmdLnOpt{'xms-loglevel'} !~ /^\s*(ERROR|WARN|NOTICE|INFO|DEBUG)\s*/ ) {
        print "XMS log level $CmdLnOpt{'xms-loglevel'} is not a recognized level. (Expected ERROR | WARN | NOTICE | INFO | DEBUG )\n";
        return;
    }

    if ( $CmdLnOpt{'xms-optsrv'} ) {
        my @services = split( ' ', $CmdLnOpt{'xms-optsrv'} );

        #foreach (@services) { print $_ , "\n"};
        if ( scalar @services > 1 and /^(ALL|NONE)/ ~~ @services ) {
            print "Ambigous optional services request\n";
            return;
        }
    }

    # quiet mode implies a 'yes' answer to all questions
    if ( $CmdLnOpt{'quiet'} ) {
        $CmdLnOpt{'yes'} = 1;
    }

    if ( $CmdLnOpt{'quiet'} ) { open( $ConFd, '>', '/dev/null' ) }

    return 1;

}
#
# signal handling
#
sub SIG_Cleanup_handler {
    my ($sig) = @_;

    # clean up , log message and close logs
    log_msg( LL_WARNING, "Caught signal SIG$sig : Operation aborted." );
    exit_cleanup(1);
}

sub SIG_Die_handler {
    my ($msg) = @_;

    # clean up , log message and close logs
    log_msg( LL_ERROR, "Fatal Error: $msg" );
    exit_cleanup(1);
}

sub SIG_Warn_handler {
    my ($msg) = @_;

    # clean up , log message and close logs
    log_msg( LL_WARNING, "$msg" );
}

#
# logging
#

my $logged_errors   = 0;
my $logged_warnings = 0;
my $Logger;

sub log_init {

    eval {
        require Log::Message;
        Log::Message->import();
        1;
      }
      or do {
        my $error = $@;
        print "\nThis script requires the perl Log::Message module (perl-Log-Message-*.x86_64.rpm) available in your Linux distribution\n";
        exit 1;
      };

    if ( !( $Logger = Log::Message->new( private => 1, level => 'log' ) ) ) {
        print "Error initializing log file";
        return;
    }

    my $date = localtime();
    $date =~ s/\d\d:\d\d:\d\d\s//;
    $Logger->store( message => "XMS installation management started $date",
                    tag     => LL_INFO,
                    level   => 'log',
    );

    # verify that we can write the log file
    if ( !File::Spec->file_name_is_absolute($Xms_Log_File) ) {
        $Xms_Log_File = File::Spec->rel2abs($Xms_Log_File);
    }
    my ( $volume, $dir, $file ) = File::Spec->splitpath($Xms_Log_File);
    if ( $CmdLnOpt{'log'} and !-w $dir ) {
        print "Error: $dir is not writable\n";
        return;
    }
    return 1;
}

# log a message to the message stack
# level : LL_xxxxx
#
my @level_name = qw( NONE ERROR WARN1 INFO1 INFO2 INFO3 DEBUG);

sub log_msg {

    my $msg_tag = shift;
    my $msg = join( '', @_ );

    $Logger->store( message => $msg,
                    tag     => $msg_tag,
                    level   => 'log'
    );

    if ( $msg_tag <= $Xms_Log_Level ) {
        print $ConFd $level_name[$msg_tag], ': ', $msg, "\n";
    }

    if    ( $msg_tag == LL_ERROR )   { $logged_errors++ }
    elsif ( $msg_tag == LL_WARNING ) { $logged_warnings++ }

}

sub log_close {
    my @msg_list;

    log_msg( LL_INFO, "Operation completed with $logged_errors errors and $logged_warnings warnings\n" );

    if ( $logged_errors or $logged_warnings ) {
        print $ConFd "INFO1: See $Xms_Log_File for details\n";
    }

    @msg_list = $Logger->flush();

    if ( $CmdLnOpt{'log'} ) {
        open( my $LOGFILE, $CmdLnOpt{'append'} ? '>>' : '>', $Xms_Log_File );

        # log file is always at least verbose
        foreach my $msg_item (@msg_list) {
            if ( $msg_item->tag <= LL_VERBOSE or $msg_item->tag <= $Xms_Log_Level ) {
                print $LOGFILE ( log_format_file_msg($msg_item) );
            }
        }
        close($LOGFILE);
    }
}

sub log_format_file_msg {
    my $msg_item  = shift;
    my $timestamp = ( $msg_item->when =~ /(\d\d:\d\d:\d\d)/ ) ? $1 : '';
    my $msg       = join( ' ', $timestamp, $level_name[ $msg_item->tag ], " ", $msg_item->message, "\n" );

    return $msg;
}

sub log_format_console_msg {
    my $msg_item = shift;
    my $msg = join( ' ', $level_name[ $msg_item->tag ] . ':', $msg_item->message, "\n" );

    return $msg;
}

# prints messages to stdout that
# match the tag
sub log_print_con {
    my $ltag = shift;

    my @msg_list = $Logger->retrieve( tag => $ltag );
    foreach my $msg_item (@msg_list) {
        if ( $msg_item->tag <= $Xms_Log_Level ) {
            print $ConFd log_format_console_msg($msg_item);
        }
    }
}

#
# Execute a command and log stderr
# log stdout at DEBUG log level
# return true if successfull
#

sub exec_log_stderr {
    my $bin    = shift;
    my @params = @_;
    my $rc;
    my $tsof = '/dev/null';
    $bin = `which $bin`;
    chomp($bin);

    if ( !-x $bin ) {
        log_msg( LL_ERROR, "Can't locate executable: $bin" );
        return;
    }

    my $tef = File::Temp->new( EXLOCK => 0 );
    if ( $Xms_Log_Level == LL_DEBUG ) {
        $tsof = File::Temp->new( EXLOCK => 0 );
    }

    # note: if selinux is enforcing , stderr is not redirected
    my $cmd = join( ' ', $bin, @params, "2> $tef 1> $tsof" );

    log_msg( LL_DEBUG, "exec_log_stderr cmd: $cmd" );
    if ( $rc = system($cmd) ) {
        if ( $rc == -1 ) {
            log_msg( LL_ERROR, "Can't exec $cmd" );
        }
        else {
            log_msg( LL_DEBUG, "exec_log_stderr: $cmd returned: ", $rc >> 8 );
        }
    }

    if ($rc) {
        while ( my $line = <$tef> ) {
            chomp($line);
            log_msg( LL_ERROR, $line );
        }
    }

    if ( $Xms_Log_Level == LL_DEBUG ) {
        while ( my $line = <$tsof> ) {
            chomp($line);
            if ($line) { log_msg( LL_DEBUG, $line ); }
        }
    }
    return $rc == 0;
}

#
# Remove a directory tree from the file system
#
sub utl_remove_tree {
    my $xdir = shift;
    my $rc   = 1;

    if ( -e $xdir ) {
        remove_tree( $xdir, { error => \my $errs } );
        if (@$errs) {
            for my $file_msg (@$errs) {
                my ( $file, $msg ) = %$file_msg;
                if ( $file eq '' ) {
                    log_msg( LL_ERROR, "Error removing $xdir: $msg" );
                }
                else {
                    log_msg( LL_ERROR, "Can't unlink $file: $msg" );
                }

            }
            $rc = 0;
        }
        else {
            log_msg( LL_VVERBOSE, "Removed dir: $xdir" );
        }
    }

    return $rc;
}
#
# Operating system configuration tasks
#

# check or configure (disable) selinux for XMS
# check returns true if selinux is diabled in the config file
# and is currently not enforcing
#
sub cfg_selinux {
    my $action         = shift;
    my $selconf        = '/etc/selinux/config';
    my $selconf_bak    = $selconf . $Conf_File_Backup_Ext;
    my $sel_filestatus = 0;
    my $sel_status     = 0;

    # get selinux config file setting
    if ( -e $selconf ) {
        if ( open( my $selcnfh, '<', $selconf ) ) {
            while ( my $line = <$selcnfh> ) {
                next unless $line =~ /^\s*SELINUX\s*=\s*disabled/;
                $sel_filestatus = 1;
                last;
            }
            close($selcnfh);
        }
        else {
            log_msg( LL_ERROR, "Could not open $selconf for reading" );
            return $sel_filestatus;
        }

        # get current runtime setting as well
        if ( -x '/usr/sbin/getenforce' ) {
            my $enforce = `/usr/sbin/getenforce`;
            $sel_status = $enforce =~ /^disabled|permissive/i;
        }
        else {
            $sel_status = 1;
        }
    }
    else {
        return 1;
    }

    if ( $action == OSCA_CHECK ) {
        return $sel_status && $sel_filestatus;
    }
    else {
        # change current policy
        if ( !$sel_status ) {
            if ( system('/usr/sbin/setenforce 0') ) {
                log_msg( LL_ERROR, "Could not turn SELINUX enforcing off" );
            }
            else {
                $sel_status = 1;
            }
        }

        if ( !$sel_filestatus ) {
            if ( copy( $selconf, $selconf_bak ) ) {
                if ( open( my $selcnfbakh, '<', $selconf_bak ) ) {
                    if ( open( my $selcnfh, '>', $selconf ) ) {
                        while ( my $line = <$selcnfbakh> ) {
                            if ( $line =~ s/^\s*SELINUX\s*=\s*\w+\b/SELINUX=disabled/ ) {
                                $sel_filestatus = 1;
                            }
                            print $selcnfh $line;
                        }
                        close($selcnfh);
                    }
                    else {
                        log_msg( LL_ERROR, "Can't open file $selconf for writing: $!" );
                    }
                    close($selcnfbakh);
                }
                else {
                    log_msg( LL_ERROR, "Can't open file $selconf_bak for reading: $!" );
                }
            }
            else {
                log_msg( LL_ERROR, "Can't back up file $selconf: $!" );
            }
        }
    }
    return $sel_status and $sel_filestatus;
}

# check status of ssl.conf or configure (backup ssl.conf)
# so that xms.conf can be used instead.
# check returns true ssl.conf does not exist
sub cfg_https {
    my $action = shift;

    if ( $action == OSCA_CHECK ) {
        my $grp = $Pkg_Groups{'prereq'};
        my $pkg = $grp->get_package('mod_ssl.x86_64');
        return ( $pkg->is_installed() and !-e $Ssl_Conf_File );
    }
    elsif ( $action == OSCA_CONFIGURE ) {
        if ( -e $Ssl_Conf_File ) {
            if ( !move( $Ssl_Conf_File, $Ssl_Conf_File_Bk ) ) {
                log_msg( LL_ERROR, "Can't rename $Ssl_Conf_File to $Ssl_Conf_File_Bk" );
            }
            else {
                log_msg( LL_VERBOSE, "$Ssl_Conf_File renamed to $Ssl_Conf_File_Bk" );
                return 1;
            }
        }
        else { return 1; }
    }
    return;
}

# check status or configure fw ports
# todo future: implement some basic rule managment
#

sub cfg_firewall {
    my $action = shift;
    if ( $action == OSCA_CHECK ) {

        # Not implemented : force to condition not satisfied
        return;
    }
    elsif ( $action == OSCA_CONFIGURE ) {

        # not implemented: force to failure
        return;
    }
    return;
}

#
# Check and/or install prerequisite packages
#
sub cfg_os_pkg_prereq {
    my $action = shift;
    my $rc     = 0;

    my $grp              = $Pkg_Groups{'prereq'};
    my @missing_packages = $grp->get_not_installed();

    if ( scalar @missing_packages == 0 ) {
        return 1;
    }

    if ( $action == OSCA_CONFIGURE ) {

        # handle libjpeg special case. If required , install from supplied packages before
        # installing from repository to avoid libjpeg-turbo being installed instead.
        if ( my $pkg = $grp->get_package('libjpeg.i686') ) {
            if ( !$pkg->is_installed() ) {
                $pkg->install();
                $grp->refresh_status();
            }
        }

        #try to install the packages with automatic prerequisite dependency installation (Yum)
        if ( ::is_yum_setup() ) {
            if ( ( $rc = $grp->install_from_repos() ) == 0 ) {
                log_msg( LL_INFO, "One or more prerequisites could not be installed from configured repositories" );
            }
        }
        else {
            log_msg( LL_INFO, "Yum has no repositories configured" );
        }

        if ( !$rc and is_distro('CentOS') ) {

            # the auto prereq install did not install one or more prerequisites or
            # Yum is not configured
            # Attempt to satisfy prerequisites from included pkgs in the xms distribution
            # This distribution only contains enough prerequisites
            # to update a previous XMS ISO based installation.

            log_msg( LL_INFO, "Attempting to satisfy prerequisites from included packages" );
            @missing_packages = $grp->get_not_installed();
            if ( scalar @missing_packages == grep { $_->filename() } @missing_packages ) {

                # first , handle the special case of openssl.i686 files conflicting with openssl.x86_64
                # if x86_64 is already installed , install i686 without the conflicting doc files
                $grp->refresh_status();
                if ( my $pkg32 = $grp->get_package('openssl.i686') ) {
                    if ( !$pkg32->is_installed() ) {
                        my $pkg64 = $grp->get_package('openssl.x86_64');
                        if ( $pkg64->is_installed() ) {
                            my $v32 = $pkg32->file_version() . '-' . $pkg32->file_release();
                            my $v64 = $pkg64->inst_version() . '-' . $pkg64->inst_release();
                            if ( $v32 ne $v64 ) {
                                log_msg( LL_ERROR,
                                         "The included openssl.i686 package version ($v32) does not match the installed openssl.x86_64 version ($v64)" );
                                log_msg( LL_ERROR, "Obtain and install openssl-$v64.i686.rpm and try again" );
                                return;
                            }
                            else {
                                if ( !$pkg32->install_exclude_docs() ) {
                                    log_msg( LL_ERROR, "Can't install openssl.i686" );
                                    return;
                                }
                                $grp->refresh_status();
                            }
                        }
                    }
                }
                else {
                    log_msg( LL_WARNING, 'Could not get package information for openssl.i686' );
                }

                # install the supplied prerequisites
                if ( ( $rc = $grp->install() ) == 0 ) {
                    log_msg( LL_ERROR, "Failed to install supplied prerequisites" );
                }
            }
            else {
                log_msg( LL_ERROR, "One or more required prerequisite OS packages are not included in this XMS distribution" );
                log_msg( LL_INFO,  "Either configure a Yum repository with the necessary packages or obtain and install prerequisites manually" );
            }
        }

        if ($rc) {

            # The 32 bit nss package requires (Temporary) special treatment on x64 systems:
            #    - if nss.i686 3.12 is installed , we need to install the nss-sysinit.3.12.i686 package
            #      so that the 32 bit nss system gets initialized.
            #    - on x64 systems , nss 3.13 and higher uses nss-sysinit.x86_64 to initialize both i686 and x64 versions
            #      and does not require nss-sysinit.i686 to be installed
            #    - nss-sysinit.i686 (supplied) is not part of CentOS x86_64 distribution (only nss-sysinit.x86_64 is)

            $grp->refresh_status();
            my $pkg = $grp->get_package('nss.i686');
            if ($pkg) {
                if ( $pkg->is_installed() ) {
                    my ( $major, $minor, $rest ) = split( '\.', $pkg->inst_version(), 3 );
                    log_msg( LL_DEBUG, "Currently installed nss package version: $major.$minor " );
                    if ( $minor == 12 ) {
                        $pkg = $Pkg_Groups{'prereq_special'}->get_package('nss-sysinit.i686');
                        if ( !$pkg->is_installed() ) {
                            log_msg( LL_VERBOSE, 'nss.i686 version is 3.12.  Installing nss-sysinit.i686' );
                            if ( !$pkg->install() ) {
                                log_msg( LL_ERROR, "Can't install nss-sysinit.i686" );
                                return;
                            }
                        }
                    }
                }
                else {
                    log_msg( LL_ERROR, 'prerequisite installation:  nss.i686 is not installed' );
                    return;
                }
            }
            else {
                log_msg( LL_ERROR, 'Failed to get nss package info' );
                return;
            }
        }
        else {
            # log missing prerequisites
            $grp->refresh_status();
            if ( @missing_packages = $grp->get_not_installed() ) {
                ::log_msg( ::LL_INFO, 'The following required OS prerequisite packages remain not installed:' );
                foreach my $pkg (@missing_packages) {
                    ::log_msg( ::LL_INFO, sprintf( "    %-20s %s", $pkg->name(), $pkg->arch() ) );
                }
            }
        }
    }
    return $rc;
}

#
# check and optionally configure the hostname in /etc/hosts
#
sub cfg_hosts {
    my $setup             = shift;
    my $hosts_file        = "/etc/hosts";
    my $hosts_file_backup = "/etc/hosts$Conf_File_Backup_Ext";
    my $foundV4           = 0;

    my $hname = `hostname`;
    chomp($hname);

    if ( open( my $hstsfh, "<", $hosts_file ) ) {
        while ( my $line = <$hstsfh> ) {
            $line =~ s/\s*#.*//;
            next if $line =~ /^\s*$/;
            my ( $address, @names ) = split( ' ', $line );
            if ( grep { /$hname/ } @names ) {
                if ( $address =~ /\d+\.\d+\.\d+\.\d+/ ) {
                    $foundV4 = 1;
                }
            }
        }
        close($hstsfh);
    }

    if ( !$foundV4 && $setup ) {
        my @intf         = ();
        my %intf_addr    = ();
        my $host_address = '';
        if ( open( my $output, 'ip address 2>/dev/null | ' ) ) {
            while ( my $line = <$output> ) {
                next unless $line =~ /^\s*inet\s+(\d+\.\d+\.\d+\.\d+).+\s+(\w+\d+)$/;
                $intf_addr{$2} = $1;
                push @intf, $2;    # keep the order of appearance
            }

            if    ( exists $intf_addr{'eth0'} ) { $host_address = $intf_addr{'eth0'} }
            elsif ( exists $intf_addr{'br0'} )  { $host_address = $intf_addr{'br0'} }
            elsif ( scalar @intf )              { $host_address = $intf_addr{ $intf[0] } }
        }

        if ( !$host_address ) {
            log_msg( LL_WARNING, "Could not obtain IP address information for /etc/hosts update" );
            return;
        }

        if ( copy( $hosts_file, $hosts_file_backup ) ) {
            if ( open( my $hsts_bupfh, "<", $hosts_file_backup ) ) {
                if ( open( my $hstsfh, ">", $hosts_file ) ) {
                    print $hstsfh "$host_address   $hname\n";
                    while ( my $line = <$hsts_bupfh> ) {
                        print $hstsfh $line;
                    }
                    close($hstsfh);
                    close($hsts_bupfh);
                    $foundV4 = 1;
                    log_msg( LL_VERBOSE, "Added $host_address $hname to /etc/hosts" );
                }
            }
        }
        else {
            log_msg( LL_ERROR, "Can't backup $hosts_file :$!" );
            return;
        }
    }
    return $foundV4;
}

#
# Process the pre-installation OS configuration tasks
#
sub cfg_process_os_cfg {

    if ( !is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        log_msg( LL_DEBUG, 'Operating mode is not "install" or "update".  OS configuration not required.' );
        return 1;
    }

    log_msg( LL_INFO, "Processing platform configuration" );

    # configure selinux
    if ( !cfg_selinux(OSCA_CHECK) ) {
        if ( $CmdLnOpt{'cfg-selinux'} ) {
            if ( !cfg_selinux(OSCA_CONFIGURE) ) {
                log_msg( LL_ERROR, "Error disabling SELINUX" );
                return;
            }
            else {
                log_msg( LL_VERBOSE, "SELINUX is now disabled" );
            }
        }
        else {
            log_msg( LL_ERROR, "Disable SELINUX manually before installing XMS" );
            return;
        }
    }

    # configure /etc/hosts
    if ( !cfg_hosts(OSCA_CHECK) ) {
        if ( $CmdLnOpt{'cfg-hosts'} ) {
            if ( !cfg_hosts(OSCA_CONFIGURE) ) {
                log_msg( LL_ERROR, "Error configuring /etc/hosts. Configure hostname in /etc/hosts manually" );
            }
            else {
                log_msg( LL_VERBOSE, "/etc/hosts file configured successfully." );
            }
        }
        else {
            log_msg( LL_WARNING, "Configure hostname in /etc/hosts manually before running XMS" );
        }
    }

    # configure firewall
    if ( is_install_mode(IM_INSTALL) and !cfg_firewall(OSCA_CHECK) ) {
        if ( $CmdLnOpt{'firewall'} ) {
            if ( !cfg_firewall(OSCA_CONFIGURE) ) {
                log_msg( LL_ERROR, "Error configuring firewall. Configure firewall manually" );
            }
            else {
                log_msg( LL_VERBOSE, "Firewall configured successfully." );
            }
        }
        else {
            log_msg( LL_INFO, "Open Firewall ports required: ", $Xms_Fw_Ports_T, ' ', $Xms_Fw_Ports_U );
            log_msg( LL_WARNING, "Ensure firewall ports are open before running XMS" );
        }
    }

    # configure package prerequisites
    if ( !cfg_os_pkg_prereq(OSCA_CHECK) ) {

        if ( $CmdLnOpt{'cfg-prereq'} ) {
            log_msg( LL_INFO, "Installing OS prerequisites (please wait)" );
            if ( !cfg_os_pkg_prereq(OSCA_CONFIGURE) ) {
                log_msg( LL_ERROR, "Pre-requisite package installation failed. Manually install missing packages listed in the log" );
                $Errno = E_GEN_PREREQUISITES;
                return;
            }
            else {
                log_msg( LL_VERBOSE, "Prerequisite OS packages installed successfully." );
            }
        }
        else {

            log_msg( LL_WARNING, "Install prerequisite packages listed in the log manually before installing XMS" );
            return;
        }
    }

    # After prerequisites are installed , rename ssl.conf if it exists
    if ( !cfg_https(OSCA_CHECK) ) {
        if ( $CmdLnOpt{'cfg-https'} ) {
            if ( !cfg_https(OSCA_CONFIGURE) ) {
                log_msg( LL_ERROR, "Error preparing for https config" );
                return;
            }
            else {
                log_msg( LL_VERBOSE, "https config prep completed" );
            }
        }
        else {
            log_msg( LL_WARNING, "user refused httpd ssl auto config: $Ssl_Conf_File must be removed or merged with xms.conf manually" );
        }
    }
    return 1;
}

#
# pre installation setup tasks
#
sub pre_process_tasks {

    if ( is_install_mode(IM_REMOVE) ) {
        log_msg( LL_INFO, "Starting removal of XMS version $Xms_Installed_Version ..." );
    }
    else {
        log_msg( LL_INFO, "Starting ", is_install_mode(IM_UPDATE) ? 'update to' : 'installation of', " XMS version $Xms_File_Version ..." );
    }

    if ( !is_install_mode( IM_INSTALL | IM_TEST ) ) {
        log_msg( LL_INFO, "Stopping XMS Services" );

        if ( !$Nodecontroller->stop() ) {
            log_msg( LL_ERROR, "nodecontroller service failed to stop. " );

            # don't quit on errors if removing
            if ( !is_install_mode(IM_REMOVE) ) {
                return;
            }
        }

        # keep the OS service controller honest
        if ( $Nodecontroller->is_running() ) {
            log_msg( LL_WARNING, "nodecontroller still running after service stop. Killing." );
            if ( !$Nodecontroller->kill() ) {
                log_msg( LL_ERROR, "Failed to kill nodecontroller" );
            }
            if ( $Nodecontroller->is_running() ) {
                log_msg( LL_ERROR, "Nodecontroller refuses to die" );
            }
        }
        $OS_Services{'lighttpd'}->stop();
        $XMS_Services{'snmpsubagent'}->stop();
        `umount  /var/lib/xms/meters`;
    }
    return cfg_process_os_cfg();
}

#
#  post installation setup tasks
#

sub post_process_tasks {
    my $errors = 0;

    # setup lighttpd
    pst_task_lighttpd() or $errors++;

    # filesystem links
    pst_task_links() or $errors++;

    # www log cleanout cron job
    pst_task_cron() or $errors++;

    # httpd configuration
    pst_task_httpd() or $errors++;

    # XMS bind address and port
    pst_task_bind_addr_port( $CmdLnOpt{'xms-bindaddr'}, $CmdLnOpt{'xms-bindport'} ) or $errors++;

    # XMS logging location and level
    pst_task_xms_log_dir( $CmdLnOpt{'xms-logdir'} )     or $errors++;
    pst_task_xms_log_level( $CmdLnOpt{'xms-loglevel'} ) or $errors++;

    # Setup logrotate to manage logs
    pst_task_logrotate( $CmdLnOpt{'xms-logdir'} ? $CmdLnOpt{'xms-logdir'} : '/var/log/xms' ) or $errors++;

    # cleanout old perfmods.pl  created entries from /etc/profile
    pst_task_perfmod_cleanup() or $errors++;

    # reset legacy ephemeral port range setting to system default 32768 61000
    pst_task_legacy_eph_port_cleanup() or $errors++;

    # Setup OS performance parameters
    pst_task_perfmods() or $errors++;

    # XMS verification demo
    pst_task_verif_demo() or $errors++;

    # SNMP subagent
    pst_task_snmpsubagent() or $errors++;

    # Perf Manager
    pst_task_perfmanager() or $errors++;
       
    if ( $errors and !is_install_mode(IM_REMOVE) ) {
        log_msg( LL_WARNING, "Non-fatal errors occured during post processing. Removal and re-installation may be required" );
    }

    if ( $CmdLnOpt{'bn4k'} ) {
        if ( !pst_task_bn4k( $CmdLnOpt{'bn4k'}, 1 ) ) {
            log_msg( LL_WARNING, 'BN4K setup unsuccessfull' );
        }
    }

    # Library configuration
    system('/sbin/ldconfig');

    #  Service control
    pst_task_services();

    pst_task_complete();
    log_msg( LL_VERBOSE, "Post processing tasks completed successfully" );

    return 1;
}

#
# Verification Demo
#
sub pst_task_verif_demo {
    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ( !copy( $Xms_Pkg_Dir . '/verification', '/usr/bin' ) ) {
            ::log_msg( ::LL_WARNING, "Could not copy webrtc verification demo: $!" );
            return;
        }
        else {
            chmod( 0755, '/usr/bin/verification' );
            log_msg( ::LL_VVERBOSE, 'webrtc verification demo: OK' );
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        if ( -e '/usr/bin/verification' and !unlink('/usr/bin/verification') ) {
            ::log_msg( ::LL_WARNING, "Could not remove webrtc verification demo: $!" );
            return;
        }
        else {
            ::log_msg( LL_VERBOSE, "Verification demo removed: OK" );
        }
    }
    return 1;
}

#
# Service Setup
#
sub pst_task_services {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        $OS_Services{'snmpd'}->stop();
        $OS_Services{'snmptrapd'}->stop();

        foreach my $srv ( values %OS_Services ) {
            $srv->enable();
            $srv->start();
        }

        sleep(2);
        exists( $OS_Services{'httpd'} ) and $OS_Services{'httpd'}->reload();

        $XMS_Services{'snmpsubagent'}->start();

        # Add nodecontroller service under chkconfig control
        if ( !$Nodecontroller->add() ) {
            return;
        }

        log_msg( LL_INFO, "Starting XMS Services" );

        if ( !$Nodecontroller->start() ) {
            log_msg( LL_ERROR, "XMS Services start failed" );
            return;
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {

    }
    return 1;
}

#
# setup filesystem links
#
sub pst_task_links {
    my $rc = 1;

    # link -> target
    my %linknames = ( '/lib/libjs.so'                          => '/usr/lib/libjs.so.1',
                      '/var/www/xms/var'                       => '/var',
                      '/var/lib/xms/media/en_US'               => '/var/lib/xms/media/en-US',     
    );

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        foreach my $lnk ( keys %linknames ) {
            if ( !-l $lnk && !symlink( $linknames{$lnk}, $lnk ) ) {
                log_msg( LL_ERROR, "Failed to symlink $lnk : $!" );
                $rc = 0;
            }
            else {
                log_msg( LL_VVERBOSE, "symbolic link $lnk -> $linknames{$lnk} setup OK" );
            }
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        foreach my $lnk ( keys %linknames ) {
            if ( -e $lnk and !unlink($lnk) ) {
                ::log_msg( ::LL_WARNING, "Could not remove link $lnk: $!" );
                $rc = 0;
            }
            else {
                ::log_msg( LL_VVERBOSE, "Removed link $lnk: OK" );
            }
        }
    }
    return $rc;
}

#
# cron Setup
#
sub pst_task_cron {
    my $rc = 1;
    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        system('crontab -l | grep -v /var/www/xms/cleanzip.sh | crontab  -');    #remove lagacy one
        if ( !copy( '/var/www/xms/cleanzip.sh', '/etc/cron.daily' ) ) {
            log_msg( LL_ERROR, "Failed to setup cleanup cron job: $!" );
            $rc = 0;
        }
        else {
            chmod( 0744, '/etc/cron.daily/cleanzip.sh' );
            log_msg( LL_VVERBOSE, 'cleanup cron job setup: OK' );
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        if ( -e '/etc/cron.daily/cleanzip.sh' and !unlink('/etc/cron.daily/cleanzip.sh') ) {
            log_msg( LL_ERROR, "Error removing cron job" );
            $rc = 0;
        }
        else {
            log_msg( LL_VVERBOSE, 'cleanup cron job removed: OK' );
        }
    }
    return $rc;
}

#
# lighttpd setup
#
sub pst_task_lighttpd {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {

        # setup lighttpd
        # since we supply lighttpd we assume the config file is ours
        # so there is no need to backup the existing conf file.
        # also setup the passwd file deposited in /tmp by restful

        foreach my $sfile ( 'lighttpd.conf', 'lighttpd-htpasswd.user' ) {
            if ( !-e '/tmp/' . $sfile ) {
                log_msg( LL_ERROR, "/tmp/$sfile not present" );
            }
            elsif ( !move( '/tmp/' . $sfile, '/etc/lighttpd' ) ) {
                log_msg( LL_ERROR, "Failed to setup $sfile : $!" );
                return;
            }
        }

        my $lighttpd_ssl_dir = '/etc/lighttpd/ssl';
        if ( !-e $lighttpd_ssl_dir and !mkdir $lighttpd_ssl_dir, 0755 ) {
            log_msg( LL_ERROR, "Failed to create $lighttpd_ssl_dir: $!" );
            return;
        }

        foreach my $ext ( 'key', 'crt', 'pem' ) {
            if ( !move( '/tmp/xms.' . $ext, $lighttpd_ssl_dir ) ) {
                log_msg( LL_ERROR, "Failed to move /tmp/xms.$ext to $lighttpd_ssl_dir : $!" );
                return;
            }
        }

        log_msg( LL_VVERBOSE, "lighttpd setup files: OK" );

    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        my $rc = utl_remove_tree('/etc/lighttpd');
        log_msg( LL_VVERBOSE, "lighttpd setup files removed:", $rc ? "OK" : "FAILED" );
    }

    return 1;
}

#
# configure startup of optional services
#
sub pst_task_xms_opt_srv {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {

        #disable optional services
        my $srv_ntv_conf_name = '/etc/xms/nodecontroller/services-native.conf';
        if ( !copy( $srv_ntv_conf_name, $srv_ntv_conf_name . '.' . $Xms_File_Version ) ) {
            log_msg( LL_ERROR, "Could not backup services-native.conf before disabling optional services" );
            return;
        }

        my $srv_ntf_cfg = CfgFile->new( file => $srv_ntv_conf_name );
        if ($srv_ntf_cfg) {
            foreach my $sect ( 'httpclient', 'mrcpclient', 'rtcweb', 'xmrest', 'netann', 'msml', 'vxml', 'verification' ) {
                if ( $srv_ntf_cfg->set_value( $sect, 'onStart', 'no' ) ne 'no' ) {
                    log_msg( LL_ERROR, "Can't set onStart for [$sect] in $srv_ntv_conf_name" );
                    return;
                }
                else { log_msg( LL_VERBOSE, "BN4K setup: Disabled $sect service" ); }
            }

            if ( $srv_ntf_cfg->write_file() ) {
                log_msg( LL_VVERBOSE, "BN4K setup: $srv_ntv_conf_name updated successfully" );
            }
            else {
                log_msg( LL_ERROR, "BN4K setup: Error writing $srv_ntv_conf_name" );
                return;
            }
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {

    }

    return 1;
}

#
# configure snmpsubagent
#
sub pst_task_snmpsubagent {
    my $snmpd_local     = "/etc/snmp/snmpd.local.conf";
    my $snmpd_local_xms = "/etc/xms/snmpsubagent/snmpd.local.conf";

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ( -e $snmpd_local ) {
            copy( $snmpd_local, $snmpd_local . $Conf_File_Backup_Ext );
        }
        if ( !copy( $snmpd_local_xms, $snmpd_local ) ) {
            log_msg( LL_ERROR, "Can't copy $snmpd_local_xms to $snmpd_local: $!" );
            return;
        }

        $XMS_Services{'snmpsubagent'}->add()    or return;
        $XMS_Services{'snmpsubagent'}->enable() or return;
    }

    return 1;
}

#
# configure perfmanager
#
sub pst_task_perfmanager {
    my $bin = `which mount`;
    chomp($bin);
    my $meters_path = "/var/lib/xms/meters";
    my $meters_path_re = quotemeta($meters_path);
    my $mounted = 0;
    my $fstab_setup = 0;

    if ( -x $bin and open( my $outp, "-|", $bin )) {      
            foreach my $line (<$outp>) {
                if ( $line =~ /^tmpfs\s+on\s+$meters_path_re/ ) {
                    log_msg( LL_VVERBOSE, 'permanager meters dir already mounted' );
                    $mounted = 1;
                    last;
                }
            }
            close($outp);
    } else {
        log_msg( LL_ERROR , "Can't execute $bin");
        return;
    }
    
    if ( open( my $fsth, "<", "/etc/fstab" )) {
        while ( my $line = <$fsth> ) {
                next unless $line =~ /^\s*tmpfs\s+$meters_path_re/;
                $fstab_setup = 1;
                log_msg( LL_VVERBOSE, 'permanager fstab already setup' );
                last;
            }
        close($fsth);      
    } else {
        log_msg( LL_ERROR , "Can't open /etc/fstab for reading");
        return;
    }
        
    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if(! $mounted) {
            if(!exec_log_stderr($bin,"-t tmpfs tmpfs $meters_path" )) {
                log_msg( LL_ERROR , "Can't mount tmpfs $meters_path");
                return ;
            } else {log_msg( LL_VVERBOSE, "Mounted $meters_path OK");}
        }
        
        if(! $fstab_setup)  {
            if ( open( my $fsth, ">>", "/etc/fstab" )) {
                print $fsth "tmpfs                   $meters_path     tmpfs   defaults        0 0\n";
                log_msg( LL_VVERBOSE, "perfmanager fstab setup OK");
                close($fsth);                    
            }
        }
    } elsif (is_install_mode( IM_REMOVE)) {
         if($fstab_setup)  {
             if(copy("/etc/fstab" , "/etc/fstab.xms_bak")) {
                 if(open (my $fstbbkh , "<", "/etc/fstab.xms_bak")) {
                     if(open(my $fstbh ,">" ,"/etc/fstab")) {
                         while ( my $line = <$fstbbkh>) {
                             next if $line =~ /^\s*tmpfs\s+$meters_path_re/;
                             print $fstbh $line;
                         }
                         close($fstbh);
                     }else { log_msg( LL_ERROR , "Can't open /etc/fstab for writing");}
                     close($fstbbkh);
                 } else {log_msg( LL_ERROR, "Can't open /etc/fstab.xms_bak");}
             } else { log_msg( LL_ERROR , "Can't back up /etc/fstab");}
         }                  
    }
    
    return 1;
}

#
# Log rotation
#

sub pst_task_logrotate {
    my $log_dir         = shift;
    my $lgr_script_file = '/etc/logrotate.d/xms';

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        $log_dir or return;

        my $rotate_script = <<END_ROTATE;
$log_dir/*.log {
daily
maxage 7
missingok
rotate 0
nocreate
sharedscripts
postrotate
kill -HUP \`cat /var/run/nodecontroller.pid\`
kill -HUP \`cat /var/run/appmanager.pid\`
kill -HUP \`cat /var/run/broker.pid\`
kill -HUP \`cat /var/run/xmserver.pid\`
kill -HUP \`cat /var/run/xmsrest.pid\`
kill -HUP \`cat /var/run/netann.pid\`
kill -HUP \`cat /var/run/httpclient-netann.pid\`
kill -HUP \`cat /var/run/httpclient-xmserver.pid\`
kill -HUP \`cat /var/run/mrcpclient-xmserver.pid\`
kill -HUP \`cat /var/run/vxmlinterpreter.pid\`
kill -HUP \`cat /var/run/verification.pid\`
kill -HUP \`cat /var/run/rtcweb-xmserver.pid\`
endscript
}
END_ROTATE

        if ( open( my $rotatefh, '>', $lgr_script_file ) ) {
            print $rotatefh $rotate_script;
            close($rotatefh);
            log_msg( LL_VVERBOSE, "Log rotate script $lgr_script_file setup: OK" );
        }
        else {
            log_msg( LL_ERROR, "Failed to setup log rotation script" );
            return;
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {

        if ( -e $lgr_script_file ) {
            if ( !unlink($lgr_script_file) ) {
                log_msg( LL_ERROR, "Could not remove $lgr_script_file: $!" );
                return;
            }
            else {
                log_msg( LL_VVERBOSE, "Log rotate script $lgr_script_file removed: OK" );
            }
        }
    }
    return 1;
}

#
# Cleanout legacy performance mods from /etc/profile
#
sub pst_task_perfmod_cleanup {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ( -f "/etc/profile" ) {
            log_msg( LL_VVERBOSE, "Checking /etc/profile for old performance tuning entries:" );
            open( my $fread,  '<', '/etc/profile' );
            open( my $fwrite, '>', '/etc/profile.XMSTEMPFILE' );
            my $modded = 0;
            while ( my $line = <$fread> ) {
                if (    ( $line =~ /^\s*echo\s*\d+\s*>\s*\/proc\/sys\/kernel\/shmmax\s*/i )
                     or ( $line =~ /^\s*echo\s*\d+\s*>\s*\/proc\/sys\/net\/core\/(rmem_default|rmem_max|wmem_max|wmem_default|netdev_max_backlog)\s*/i )
                     or ( $line =~ /^\s*echo\s*\d+\s*>\s*\/sys\/block\/[shv]d\w\/queue\/(nr_requests|read_ahead_kb)\s*/i )
                     or ( $line =~ /^\s*ethtool\s*\-G\s*eth\d+\s*tx\s*\d+\s*rx\s*\d+/ ) )
                {
                    $modded = 1;
                    chomp($line);
                    log_msg( LL_VVERBOSE, "   removed line: ", $line );
                    next;
                }
                print $fwrite $line;
            }

            close $fread;
            close $fwrite;
            if ($modded) {
                if ( move( '/etc/profile.XMSTEMPFILE', '/etc/profile' ) ) {
                    log_msg( LL_VVERBOSE, 'Removed legacy performance settings from /etc/profile' );
                }
                else {
                    log_msg( LL_ERROR, "Failed to remove legacy entries from /etc/profile: $!" );
                    return 0;
                }
            }
            else {
                log_msg( LL_VVERBOSE, '/etc/profile is clean' );
                unlink('/etc/profile.XMSTEMPFILE');
            }
        }
    }
    return 1;
}

#
# OS performance mods
#
sub pst_task_perfmods {
    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ( !exec_log_stderr( 'perl', "$Xms_Pkg_Dir/perfmods.pl" ) ) {
            log_msg( LL_ERROR, "Failed setting perfmods" );
            return;
        }
    }
    return 1;
}

#
#  reset legacy ephemeral port range setting to system default 32768 61000
#
sub pst_task_legacy_eph_port_cleanup {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        my $sysctl_file     = '/etc/sysctl.conf';
        my $sysctl_file_tmp = $sysctl_file . '.XMSTMPFILE';
        if ( open( my $scfile, '<', $sysctl_file ) ) {
            my $modded = 0;
            if ( open( my $scfile_tmp, '>', $sysctl_file_tmp ) ) {
                while ( my $line = <$scfile> ) {
                    if ( $line =~ s/^\s*(net\.ipv4\.ip_local_port_range\s*=)\s*60000\s+65000\s*$/$1 32768 61000\n/ ) {
                        $modded = 1;
                    }
                    print $scfile_tmp $line;
                }
                close $scfile_tmp;
            }
            close $scfile;

            if ($modded) {
                if ( move( $sysctl_file_tmp, $sysctl_file ) ) {
                    log_msg( LL_VVERBOSE, "Reset legacy ip local port range setting to default in $sysctl_file" );
                }
                else {
                    log_msg( LL_ERROR, "Can't move $sysctl_file_tmp file to $sysctl_file: $!" );
                    return 0;
                }
            }
            else {
                unlink($sysctl_file_tmp);
                log_msg( LL_DEBUG, "$sysctl_file did not contain legacy local port range setting" );
            }
        }
    }
    return 1;
}

#
# httpd configuration
#

sub pst_task_httpd {

    my $httpd_conf_src_dir    = '/var/www/xms/httpsRequiredFiles/conf.d/';
    my $httpd_conf_file       = 'xms.conf';
    my $httpd_conf_target_dir = '/etc/httpd/conf.d/';

    my $key_cert_src_dir = '/var/www/xms/httpsRequiredFiles/etcpki/pki/tls/private/';
    my $key_cert_dst_dir = '/etc/pki/tls/private/';
    my @key_cert_files   = qw(xms.key xms.csr certs/xms.crt);

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) and !$CmdLnOpt{'bn4k'} ) {
        if ( -e $httpd_conf_target_dir . $httpd_conf_file and is_install_mode(IM_UPDATE) ) {
            if ( !copy( $httpd_conf_target_dir . $httpd_conf_file, $httpd_conf_target_dir . $httpd_conf_file . '.' . $Xms_Installed_Version ) ) {
                log_msg( LL_ERROR, "Failed backing up $httpd_conf_target_dir.$httpd_conf_file" );
                return 0;
            }
            else {
                log_msg( LL_DEBUG, "Backed up existing ", $httpd_conf_target_dir . $httpd_conf_file, ' to ', $httpd_conf_file . '.' . $Xms_Installed_Version );
            }
        }

        if ( !copy( $httpd_conf_src_dir . $httpd_conf_file, $httpd_conf_target_dir ) ) {
            log_msg( LL_ERROR, "Failed to copy ", $httpd_conf_src_dir . $httpd_conf_file, ' to ', $httpd_conf_target_dir, ": $!" );
            return 0;
        }
        else { log_msg( LL_VVERBOSE, "$httpd_conf_file setup OK" ); }

        if ( !-e $key_cert_dst_dir . 'certs' and !mkdir( $key_cert_dst_dir . 'certs', 0755 ) ) {
            log_msg( LL_ERROR, "Can't create certs in $key_cert_dst_dir" );
            return 0;
        }
        else {
            foreach my $kcfile (@key_cert_files) {
                if ( !copy( $key_cert_src_dir . $kcfile, $key_cert_dst_dir . $kcfile ) ) {
                    log_msg( LL_ERROR, "Failed to copy ", $key_cert_src_dir . $kcfile, ' to ', $key_cert_dst_dir . $kcfile, ": $!" );
                    return 0;
                }
            }
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {

        # get any left over backup files
        my @xms_conf_leftovers = glob("$httpd_conf_target_dir$httpd_conf_file.*");

        # cleanup files
        foreach my $file ( $httpd_conf_target_dir . $httpd_conf_file, @xms_conf_leftovers ) {
            if ( -e $file ) {
                if ( !unlink($file) ) {
                    log_msg( LL_ERROR, "Could not remove $file: $!" );
                }
                else {
                    log_msg( LL_VVERBOSE, "Removed httpd setup file $file: OK" );
                }
            }
        }

        #restore ssl.conf if backed up
        if (     -e $Ssl_Conf_File_Bk
             and !-e $Ssl_Conf_File
             and move( $Ssl_Conf_File_Bk, $Ssl_Conf_File ) )
        {
            log_msg( LL_VVERBOSE, "Restored $Ssl_Conf_File" );
        }

        #remove certs
        foreach my $kcfile (@key_cert_files) {
            if ( -e $key_cert_dst_dir . $kcfile and !unlink( $key_cert_dst_dir . $kcfile ) ) {
                log_msg( LL_ERROR, "Failed to remove ", $key_cert_dst_dir . $kcfile, ": $!" );
                return 0;
            }
        }

    }
    return 1;
}

#
# Complete post processing
#
sub pst_task_complete {

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {

    }
    elsif ( is_install_mode(IM_REMOVE) ) {

        #remove xms dirs
        foreach my $xdir ( '/var/www/xms', '/var/lib/xms', '/etc/xms', '/var/log/xms', '/var/log/dialogic' ) {
            utl_remove_tree($xdir);
        }
    }
}

#
# bn4k specific configuration
#

sub pst_task_bn4k {
    my $path    = shift;
    my $execute = shift;
    is_install_mode( IM_INSTALL | IM_UPDATE ) or return 1;

    my %bn4k_files = ( '.'   => ['BN4000_oem.lic'],
                       'cfg' => [ 'licenseSubset.xml', 'licenseconfig.cfg' ],
                       'lib' => ['libOemBN4K.so'],
    );

    $path =~ /.+\/$/ or $path .= '/';

    if ( !$execute ) {
        my $err = 0;
        foreach my $subdir ( keys %bn4k_files ) {
            foreach my $file ( @{ $bn4k_files{$subdir} } ) {
                my $full_path = $path . $subdir . '/' . $file;
                if ( !-e $full_path ) {
                    log_msg( LL_ERROR, "BN4K: Missing File : $full_path" );
                    $err++;
                }
            }
        }
        return ( $err == 0 );
    }

    log_msg( LL_INFO, "Processing BN4K: $path" );
    print "Processing BN4K\n";
    foreach my $subdir ( 'cfg', 'lib' ) {
        foreach my $file ( @{ $bn4k_files{$subdir} } ) {
            my $full_path = $path . $subdir . '/' . $file;
            if ( !copy( $path . $subdir . '/' . $file, "/usr/dialogic/$subdir" ) ) {
                log_msg( LL_ERROR, "BN4K: Can't copy $full_path to /usr/dialogic/$subdir : $!" );
                return;
            }
        }
    }

    if ( !copy $path. 'lib/libOemBN4K.so', '/usr/dialogic/bin/' ) {
        log_msg( LL_ERROR, "BN4K: Can't copy libOemBN4K.so to /usr/dialogic/bin/ : $!" );
        return;
    }

    if ( !exec_log_stderr( 'ldconfig', '-n /usr/dialogic/lib' ) ) {
        log_msg( LL_ERROR, 'BN4K: failed to execute ldconfig' );
        return;
    }

    if ( !copy $path. 'BN4000_oem.lic', '/etc/xms/license/active/' ) {
        log_msg( LL_ERROR, "BN4K: Can't copy BN4000_oem.lic to /etc/xms/license/active/ : $!" );
        return;
    }

    if ( -e '/usr/dialogic/cfg/mitconfig/ipms_mit_license_cfg.xml' and !unlink('/usr/dialogic/cfg/mitconfig/ipms_mit_license_cfg.xml') ) {
        log_msg( LL_ERROR, "BN4K: Can't remove '/usr/dialogic/cfg/mitconfig/ipms_mit_license_cfg.xml' :  $!" );
        return;
    }

    #disable optional services
    my $srv_ntv_conf_name = '/etc/xms/nodecontroller/services-native.conf';
    if ( !copy( $srv_ntv_conf_name, $srv_ntv_conf_name . '.' . $Xms_File_Version ) ) {
        log_msg( LL_ERROR, "Could not backup services-native.conf before disabling optional services" );
        return;
    }

    my $srv_ntf_cfg = CfgFile->new( file => $srv_ntv_conf_name );
    if ($srv_ntf_cfg) {
        foreach my $sect ( 'httpclient', 'mrcpclient', 'rtcweb', 'xmrest', 'netann', 'msml', 'vxml', 'verification' ) {
            if ( $srv_ntf_cfg->set_value( $sect, 'onStart', 'no' ) ne 'no' ) {
                log_msg( LL_ERROR, "Can't set onStart for [$sect] in $srv_ntv_conf_name" );
                return;
            }
            else { log_msg( LL_VERBOSE, "BN4K setup: Disabled $sect service" ); }
        }

        if ( $srv_ntf_cfg->write_file() ) {
            log_msg( LL_VVERBOSE, "BN4K setup: $srv_ntv_conf_name updated successfully" );
        }
        else {
            log_msg( LL_ERROR, "BN4K setup: Error writing $srv_ntv_conf_name" );
            return;
        }
    }

    # disable appmanager TCP listen
    my $appm_sys_cnf_name = '/etc/sysconfig/appmanager';
    if ( !copy( $appm_sys_cnf_name, $appm_sys_cnf_name . '.' . $Xms_File_Version ) ) {
        log_msg( LL_ERROR, "BN4K setup: Could not backup $appm_sys_cnf_name" );
        return;
    }

    my $appm_sys_cnf = CfgFile->new( file => $appm_sys_cnf_name );
    if ($appm_sys_cnf) {
        foreach my $keyname ( 'api_address', 'api_port' ) {
            if ( $appm_sys_cnf->set_value( CfgFile->DEFAULT_SECTION, $keyname, '""' ) ne '""' ) {
                log_msg( LL_ERROR, "Can't set $keyname in $appm_sys_cnf_name" );
                return;
            }
            else { log_msg( LL_VERBOSE, "BN4K setup: appmanager sysconfig $keyname set to \"\" " ); }
        }

        if ( $appm_sys_cnf->write_file() ) {
            log_msg( LL_VVERBOSE, "BN4K setup: $appm_sys_cnf_name updated successfully" );
        }
        else {
            log_msg( LL_ERROR, "BN4K setup: Error writing $appm_sys_cnf_name" );
            return;
        }
    }

    return 1;
}

#
# Setup xms bind address and port
#

sub pst_task_bind_addr_port {
    my $addr               = shift;
    my $port               = shift;
    my $xmserver_conf_name = '/etc/xms/xmserver.conf';

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ( $addr or $port ) {
            if ( not -e $xmserver_conf_name ) {
                log_msg( LL_VVERBOSE, "$xmserver_conf_name does not exist. Generating." );
                if ( exec_log_stderr('/etc/xms/nodecontroller/scripts/start-xmserver.sh') ) {
                    sleep(2);
                }
            }

            if ( -e $xmserver_conf_name ) {
                if ( !copy( $xmserver_conf_name, $xmserver_conf_name . '.' . $Xms_File_Version ) ) {
                    log_msg( LL_ERROR, "Could not backup xmserver.conf before setting bind address/port" );
                    return;
                }

                my $xmserver_conf = CfgFile->new( file => $xmserver_conf_name );
                if ( !$xmserver_conf ) {
                    log_msg( LL_ERROR, "Could not load $xmserver_conf_name to set bind address/port" );
                    return;
                }
                if ($addr) {
                    if ( $xmserver_conf->set_value( 'sip', 'bindaddr', $addr ) ne $addr ) {
                        log_msg( LL_ERROR, "Can't set bindaddr to $addr in [sip] section of $xmserver_conf_name" );
                        return;
                    }
                    else { log_msg( LL_VERBOSE, "XMS bind address set to $addr" ); }
                }

                if ($port) {
                    if ( $xmserver_conf->set_value( 'sip', 'bindport', $port ) ne $port ) {
                        log_msg( LL_ERROR, "Can't set bindport to $port in [sip] section of $xmserver_conf_name" );
                        return;
                    }
                    else { log_msg( LL_VERBOSE, "XMS bind port set to $port" ); }
                }

                if ( $xmserver_conf->write_file() ) {
                    log_msg( LL_VVERBOSE, "$xmserver_conf_name updated successfully" );
                }
                else {
                    log_msg( LL_ERROR, "Error writing $xmserver_conf_name" );
                    return;
                }
            }
            else {
                log_msg( LL_WARNING, "Can't set bind address and/or port:  error starting xmserver process" );
                return;
            }
        }
    }
    return 1;
}

#
# Setup xms logging directory
#

sub pst_task_xms_log_dir {

    my $logdir        = shift;
    my $base_dir      = '/etc/sysconfig/';
    my @sys_cnf_names = ( 'appmanager', 'broker', 'xmserver', 'httpclient', 'mrcpclient', 'msml', 'vxml', 'netann', 'nodecontroller' );

    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ($logdir) {
            foreach my $syscfg_file (@sys_cnf_names) {
                $syscfg_file = $base_dir . $syscfg_file;
                next if !-e $syscfg_file;
                if ( !-e $syscfg_file . '.' . $Xms_File_Version and !copy( $syscfg_file, $syscfg_file . '.' . $Xms_File_Version ) ) {
                    log_msg( LL_ERROR, "XMS log dir setup: Could not backup $syscfg_file ($!). Skipping." );
                    next;
                }

                my $keyname = 'log_dir';
                my $scnf = CfgFile->new( file => $syscfg_file );
                if ($scnf) {
                    if ( $scnf->set_value( CfgFile->DEFAULT_SECTION, $keyname, $logdir ) ne $logdir ) {
                        log_msg( LL_ERROR, "Can't set $keyname in $syscfg_file. Skipping." );
                        next;
                    }

                    if ( $scnf->write_file() ) {
                        log_msg( LL_VVERBOSE, "XMS log dir setup: $keyname in $syscfg_file set to $logdir" );
                    }
                    else {
                        log_msg( LL_ERROR, "XMS log dir setup: Error writing $syscfg_file. Skipping." );
                        next;
                    }
                }
            }
        }
    }
    return 1;
}

#
# Setup XMS logging directory
#
sub pst_task_xms_log_level {
    my $loglevel = shift;
    my $rc       = 1;
    if ( is_install_mode( IM_INSTALL | IM_UPDATE ) ) {
        if ($loglevel) {
            my $log_config     = '/etc/xms/nodecontroller/log-level.conf';
            my $log_config_bak = $log_config . '.' . $Xms_File_Version;

            if ( copy( $log_config, $log_config_bak ) ) {
                if ( open( my $lcbakh, '<', $log_config_bak ) ) {
                    if ( open( my $lch, '>', $log_config ) ) {
                        while ( my $line = <$lcbakh> ) {
                            if ( $line =~ /^\s*(ERROR|WARN|NOTICE|INFO|DEBUG)\s*/ ) {
                                print $lch "$loglevel\n";
                                log_msg( LL_VERBOSE, "XMS log level set to $loglevel" );
                                next;
                            }
                            print $lch $line;
                        }
                        close($lch);
                    }
                    else {
                        log_msg( LL_ERROR, "Can't open file $log_config for writing: $!" );
                        $rc = 0;
                    }
                    close($lcbakh);
                }
                else {
                    log_msg( LL_ERROR, "Can't open file $log_config_bak for reading: $!" );
                    $rc = 0;
                }
            }
            else {
                log_msg( LL_ERROR, "Can't back up file $log_config: $!" );
                $rc = 0;
            }
        }
    }
    return $rc;
}

#
# obtain unresolved info from user
#

sub get_user_input {

    my $summary = '';
    my @YN      = ( 'N', 'Y' );
    my $prm     = '';
    my $quit    = 0;

    {    # new block
        if ( is_install_mode(IM_REMOVE) ) {
            if ( is_xms_installed() ) {
                $prm = "Remove Powermedia XMS version $Xms_Installed_Version ?";
            }
            elsif ( !is_installation_valid() ) {
                $prm = "XMS is partially installed. To correct the errors XMS must be removed.  Remove XMS ?";
            }
            else {
                $prm = "XMS is not installed.  Execute remove operation anyway ?";
            }
        }
        elsif ( is_install_mode(IM_UPDATE) ) {
            if ( $Xms_Installed_Version =~ /^trunk/ xor $Xms_File_Version =~ /^trunk/ ) {
                $prm = "\nUpgrading to/from an internal development version is not an officially supported scenario.";
            }
            $prm .= "\nUpdate Powermedia XMS version $Xms_Installed_Version to $Xms_File_Version ?";
        }
        elsif ( is_install_mode(IM_INSTALL) ) {
            $prm = "\nInstall Powermedia XMS version $Xms_File_Version ?";
        }
        else {
            log_msg( LL_ERROR, "Bad mode in get_user_input" );
            return;
        }

        if ( ask_user( $prm, 'yn', 'y' ) eq 'y' ) {
            if ( is_install_mode(IM_REMOVE) ) { return 1 }
        }
        else {
            $quit = 1;
            last;
        }

        if ( !check_disk_space() ) {
            log_msg( LL_ERROR, "Insufficient free disk space" );
            $quit = 1;
            last;
        }

        # Get permission to modify /etc/hosts
        if ( !cfg_hosts(OSCA_CHECK) and !defined( $CmdLnOpt{'cfg-hosts'} ) ) {
            my $response = ask_user( "\n\nXMS requires the host to be configured in /etc/hosts.\n\nAdd your host to /etc/hosts ?", 'ynq', 'y' );
            if ( $response eq 'y' ) {
                $CmdLnOpt{'cfg-hosts'} = 1;
            }
            elsif ( $response eq 'n' ) {
                $CmdLnOpt{'cfg-hosts'} = 0;
            }
            else {
                $quit = 1;
                last;
            }

            $summary .= "    Configure /etc/hosts file:         [$YN[$CmdLnOpt{'cfg-hosts'}]]\n";
        }

        # Get permission to turn off SELINUX
        if ( !cfg_selinux(OSCA_CHECK) and !defined( $CmdLnOpt{'cfg-selinux'} ) ) {
            my $response = ask_user( "\n\nXMS does not support running with selinux.\n\nDisable selinux ?", 'ynq', 'y' );
            if ( $response eq 'y' ) {
                $CmdLnOpt{'cfg-selinux'} = 1;
            }
            elsif ( $response eq 'n' ) {
                $CmdLnOpt{'cfg-selinux'} = 0;
            }
            else {
                $quit = 1;
                last;
            }
            $summary .= "    Disable Selinux:                   [$YN[$CmdLnOpt{'cfg-selinux'}]]\n";
        }

        # Not implmented -- Get permission to configure firewall

        if ( !cfg_firewall(OSCA_CHECK) and !defined( $CmdLnOpt{'cfg-firewall'} ) ) {
            my $response = ask_user(
                    "\n\nXMS requires the firewall to open ports:\n" . "    " . $Xms_Fw_Ports_T . "\n" . "    " . $Xms_Fw_Ports_U . '\n\nOpen firewall ports ?',
                    'ynq', 'y' );

            if ( $response eq 'y' ) {
                $CmdLnOpt{'cfg-firewall'} = 1;
            }
            elsif ( $response eq 'n' ) {
                $CmdLnOpt{'cfg-firewall'} = 0;
            }
            else {
                $quit = 1;
                last;
            }

            $summary .= "    Configure firewall:                [$YN[$CmdLnOpt{'cfg-firewall'}]]\n";
        }

        # get permission to replace ssl.conf with xms.conf
        if ( !cfg_https(OSCA_CHECK) and !defined( $CmdLnOpt{'cfg-https'} ) ) {
            my $response = ask_user( "\n\nXMS httpd ssl configuration is incompatible with the default httpd \n"
                                       . "ssl configuration. This installation renames /etc/httpd/conf.d/ssl.conf\n"
                                       . "and replaces it with /etc/httpd/conf.d/xms.conf.\n\n"
                                       . "Rename ssl.conf to ssl.conf$Conf_File_Backup_Ext ?",
                                     'ynq',
                                     'y'
            );

            if ( $response eq 'y' ) {
                $CmdLnOpt{'cfg-https'} = 1;
            }
            elsif ( $response eq 'n' ) {
                $CmdLnOpt{'cfg-https'} = 0;
            }
            else {
                $quit = 1;
                last;
            }
            $summary .= "    Rename ssl.conf and use xms.conf : [$YN[$CmdLnOpt{'cfg-https'}]]\n";
        }

        # Check prerequisites OS pakcages
        if ( !cfg_os_pkg_prereq(OSCA_CHECK) and !defined( $CmdLnOpt{'cfg-prereq'} ) ) {

            if ( ask_user( "\n\nOne or more required operating system packages are not installed\nInstall missing packages automatically ?", 'ynq', 'y' ) ne
                 'y' )
            {
                $CmdLnOpt{'cfg-prereq'} = 0;
                log_msg( LL_WARNING, "Install prerequisite packages listed in the log file manually before installing XMS" );
                return;
            }
            else {
                $CmdLnOpt{'cfg-prereq'} = 1;
            }

            $summary .= "    Install OS prerequisite pkgs:      [$YN[$CmdLnOpt{'cfg-prereq'}]]\n";
        }

        if ($summary) {
            if ( ask_user( "\n\nReview and confirm configuration tasks:\n$summary\nProceed ?", 'ynq', 'y' ) ne 'y' ) {
                $quit = 1;
                last;
            }
        }
    }

    if ($quit) {
        log_msg( LL_INFO, 'Operation aborted by user.' );
        return;
    }
    else {
        return 1;
    }
}

#
# package group insallation routines
#

sub process_support_pkgs {

    my $grp = $Pkg_Groups{'support'};

    log_msg( LL_INFO, 'Processing ', $grp->name(), ' packages' );

    if ( is_install_mode(IM_UPDATE) ) {
        if ( !$grp->update() ) {
            return;
        }
    }
    elsif ( is_install_mode(IM_INSTALL) ) {
        if ( $grp->install_status() == 1 ) {
            log_msg( LL_VVERBOSE, 'All ', $grp->name(), ' packages are installed' );
        }
        else {
            if ( !$grp->install() ) {
                return;
            }
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        $grp->remove();

        # ignore errors on remove
    }
    else {
        log_msg( LL_ERROR, 'Bad mode in ', $grp->name(), ' package processing' );
        return;
    }

    log_msg( LL_VERBOSE, $grp->name, ' packages processing completed' );
    return 1;
}

use File::Find;

sub backup_conf {
    my $fname = $File::Find::name;
    return unless $fname =~ m!.+?\.(conf|cfg|xml)$!;

    if ( !copy( $fname, $fname . $Conf_File_Backup_Ext ) ) {
        log_msg( LL_ERROR, "Can't backup $fname: $!" );
    }
    else { log_msg( LL_VVERBOSE, "Backed up $fname to ", $fname, $Conf_File_Backup_Ext ); }
}

sub restore_conf {
    my $fname = $File::Find::name;
    if ( $fname =~ m!.+?\.(conf|cfg|xml)$! ) {
        if ( -e $fname . $Conf_File_Backup_Ext ) {
            if (     copy( $fname, $fname . '.' . $Xms_File_Version )
                 and copy( $fname . $Conf_File_Backup_Ext, $fname ) )
            {
                log_msg( LL_VVERBOSE, "Restored $fname after upgrade" );
                unlink( $fname . $Conf_File_Backup_Ext );
            }
            else { log_msg( LL_ERROR, "Can't restore $fname: $!" ); }
        }
        else { log_msg( LL_DEBUG, "New (post upgrade) configuration file found: $fname" ); }
    }
}

sub process_xms_core_pkgs {

    my $rc = 1;

    my $grp = $Pkg_Groups{'core'};
    log_msg( LL_INFO, 'Processing ', $grp->name(), ' packages' );

    if ( is_install_mode(IM_UPDATE) ) {

        # rpm does not like text in the version string
        if ( $Xms_Installed_Version =~ /^trunk/ or $Xms_File_Version =~ /^trunk/ ) {
            $grp->no_check_ver(1);
        }

        # backup config files before updating
        find( \&backup_conf, '/etc/xms' );
        my $dbfile = '/var/www/xms/xmsdb/default.db';
        if ( !copy( $dbfile, $dbfile . $Conf_File_Backup_Ext ) ) {
            log_msg( LL_ERROR, "Failed to back up $dbfile : $!" );
        }

        if ( !$grp->update() ) {
            $rc = 0;
        }

        find( \&restore_conf, '/etc/xms' );

        if ( !copy( $dbfile . $Conf_File_Backup_Ext, $dbfile ) ) {
            log_msg( LL_ERROR, "Failed to restore default.db.  Login with default account may be required" );
        }
        else { unlink( $dbfile . $Conf_File_Backup_Ext ) }

        if ( $rc == 0 ) {

            #update failed.  conf files are restored.  bail now.
            return;
        }

        # Use the incoming version of these files
        my @incoming_conf_files = ( '/etc/xms/broker.conf', '/etc/xms/nodecontroller/services-native.conf', '/etc/xms/nodecontroller/native.conf' );
        foreach my $cnf_file (@incoming_conf_files) {
            if ( -e "$cnf_file.$Xms_File_Version" ) {
                if (     copy( $cnf_file, "$cnf_file.$Xms_Installed_Version" )
                     and copy( "$cnf_file.$Xms_File_Version", $cnf_file ) )
                {
                    log_msg( LL_VERBOSE, "Backed up previous $cnf_file and replaced with incoming version" );
                    if ( !unlink("$cnf_file.$Xms_File_Version") ) {
                        log_msg( LL_WARNING, "Could not delete $cnf_file.$Xms_File_Version: $!" );
                    }
                }
                else {
                    log_msg( LL_ERROR, "Error procssing $cnf_file durng upgrade: $!" );
                    log_msg( LL_ERROR, "Removal and re-installation of XMS may be required" );
                }
            }
        }

        #port previous mrcp config file to the new format if required
        if ( -e "/etc/xms/mrcpclient.conf.$Xms_File_Version" ) {
            if ( !( port_mrcp_conf( '/etc/xms/mrcpclient.conf', "/etc/xms/mrcpclient.conf.$Xms_File_Version", '/etc/xms/mrcpclient.conf' ) ) ) {
                log_msg( LL_ERROR, "Error(s) occured while migrating MRCP configuration. If using MRCP, removal and re-installation of XMS may be required" );
            }
            else { log_msg( LL_VERBOSE, "MRCP configuration file migration processing completed." ) }
        }
        else { log_msg( LL_VVERBOSE, "MRCP config file migration not required" ) }

        #handle voicexmlappcfg.xml config file migration
        if ( -e "/etc/xms/vxml/voicexmlappcfg.xml.$Xms_File_Version" ) {
            if ( !( port_vxmlapp_conf( '/etc/xms/vxml/voicexmlappcfg.xml', "/etc/xms/vxml/voicexmlappcfg.xml.$Xms_File_Version",
                                       '/etc/xms/vxml/voicexmlappcfg.xml' )
                 )
              )
            {
                log_msg( LL_ERROR,
                         "Error(s) occured while migrating VXML app configuration. If using VXML, removal and re-installation of XMS may be required" );
            }
            else { log_msg( LL_VERBOSE, "VXML app configuration file migration processing completed." ) }
        }
        else { log_msg( LL_VVERBOSE, "VXML app config file migration not required" ) }
    }
    elsif ( is_install_mode(IM_INSTALL) ) {
        if ( $grp->install_status() == 1 ) {
            log_msg( LL_VVERBOSE, 'All ', $grp->name(), 'packages are installed' );

        }
        else {
            if ( !$grp->install() ) {
                $rc = 0;
            }
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        $grp->remove();

        # ignore remove errors
    }
    else { log_msg( LL_ERROR, "Bad mode in XMS core component processing" ); }

    log_msg( LL_VERBOSE, "XMS core components processing completed" );
    return $rc;
}

# port current mrcp conf format to the new file format (if necessary)
# and store result in the output file

sub port_mrcp_conf {
    my ( $old_file, $new_file, $output_file ) = @_;
    my $client_addr     = undef;
    my $mrcp_conf_write = undef;

    my $mrcp_conf_new = CfgFile->new( file => $new_file );
    if ( !$mrcp_conf_new ) {
        return;
    }

    my $mrcp_conf_old = CfgFile->new( file => $old_file );
    if ( !$mrcp_conf_old or !( $client_addr = $mrcp_conf_old->get_value( 'global', 'clientaddress' ) ) ) {

    }
    elsif ( !$mrcp_conf_old->get_value( 'speechserver1', 'session' ) ) {
        log_msg( LL_VVERBOSE, "Current MRCPClient conf file is already in new format." );
        $mrcp_conf_write = $mrcp_conf_old;
    }
    elsif ( $client_addr eq '0.0.0.0' ) {
        log_msg( LL_VVERBOSE, "Current MRCPClient conf file is unmodified (default)." );
        $mrcp_conf_write = $mrcp_conf_new;
    }
    else {
        log_msg( LL_VVERBOSE, "Current MRCPClient conf file format is deprecated, porting to new format" );

        if ( my $values = $mrcp_conf_old->get_section_values('global') ) {
            $mrcp_conf_write = $mrcp_conf_new;
            $mrcp_conf_new->set_section_values( 'global', $values );
            foreach my $srvr ( 'speechserver1', 'speechserver2' ) {
                my $addr = $mrcp_conf_old->get_value( $srvr, 'address' );
                if ( $addr and ( $addr ne '127.0.0.1' ) and ( $addr ne '0.0.0.0' ) ) {
                    log_msg( LL_VVERBOSE, "Porting section [$srvr] to new format MRCPClient conf file" );
                    if ( my $values = $mrcp_conf_old->get_section_values($srvr) ) {
                        $mrcp_conf_new->set_section_values( $srvr, $values );
                    }
                    else {
                        $mrcp_conf_write = undef;
                        last;
                    }

                    if ( !$mrcp_conf_new->delete_value( $srvr, 'session' ) or ( !$mrcp_conf_new->set_value( $srvr, 'enabled', 'true' ) ) ) {
                        $mrcp_conf_write = undef;
                        last;
                    }
                }
            }
        }
    }

    if ($mrcp_conf_write) {

        # Add UDP retransmit and role support if not present
        if ( !$mrcp_conf_write->get_value( 'global', 'udpretransmittimer' ) ) {
            $mrcp_conf_write->set_value( 'global', 'udpretransmittimer',    '100' );
            $mrcp_conf_write->set_value( 'global', 'udpmaxretransmitcount', '2' );
            $mrcp_conf_write->set_value( 'global', 'serverrecoverydelay',   '5' );
        }

        #Add role if not present
        my @sections = $mrcp_conf_write->get_section_titles();
        foreach my $sec (@sections) {
            next if $sec eq 'global';
            if ( !$mrcp_conf_write->get_value( $sec, 'role' ) ) {
                $mrcp_conf_write->set_value( $sec, 'role', 'primary' );
            }
        }

        #write it out
        if ( !$mrcp_conf_write->write_file($output_file) ) {
            log_msg( LL_ERROR, "Error writing MRCP conf file ($output_file)" );
            return;
        }
    }
    else {
        # reset mrcpclient.conf to default incoming file if errors occured
        if ( !copy( $new_file, $output_file ) ) {
            log_msg( LL_ERROR, "Error resetting MRCP config to default ($new_file) -> ($output_file): $!" );
            return;
        }
        log_msg( LL_WARNING, "Current MRCP configuration file ($old_file) is missing or invalid. MRCP configuration has been reset to default." );
        log_msg( LL_WARNING, "If using MRCP, verify your MRCP server configuration in the XMS Web UI" );
    }

    return 1;
}

# port current vxmlapp conf format to the new file format (if necessary)
# and store result in the output file

sub port_vxmlapp_conf {
    my ( $old_file, $new_file, $output_file ) = @_;
    my $vers = 0;

    if ( open( my $vfh, "<", $old_file ) ) {
        while ( my $line = <$vfh> ) {
            if ( $line =~ /^\s*<\s*voicexml-app-config\s+version\s*=\s*"\s*(\d\.\d)\s*"/ ) {
                log_msg( LL_VVERBOSE, "VXML app config file version $1" );
                $vers = $1;
                last;
            }
        }
        close($vfh);
    }
    else {
        log_msg( LL_ERROR, "Can't open VXML app config file ($old_file) for processing: $!" );
        return;
    }

    if ( $vers == 1.0 and !copy( $new_file, $output_file ) ) {
        log_msg( LL_ERROR, "Error upgrading VXML app config ($new_file) -> ($output_file): $!" );
        return;
    }
    else { log_msg( LL_VERBOSE, 'VXML app config file processed' ) }

    return 1;
}

# Install HMP subsystem
sub process_hmp {
    log_msg( LL_INFO, 'Processing XMS HMP subsystem' );

    if ( is_install_mode(IM_INSTALL) ) {
        if ( !$Hmp->install() ) {
            return;
        }
        log_msg( LL_INFO, "Configuring default license (please wait)" );

        # start HMP so license can be configured
        if ( !$Hmp->start() ) {
            log_msg( LL_ERROR, "Failed to start Hmp subsystem for default configuration" );
            return;
        }
        else {
            #configure default license
            if ( !$Hmp->setup_default_lic() ) {
                return;
            }

            # configure RTP address if required
            $Hmp->setup_rtp_addr();
        }

        # stop HMP so the node controller can start it
        if ( !$Hmp->stop() ) {
            log_msg( LL_ERROR, "Failed to stop Hmp subsystem after default license configuration" );
            return;
        }
    }
    elsif ( is_install_mode(IM_UPDATE) ) {
        if ( !$Hmp->update() ) {
            return;
        }
    }
    elsif ( is_install_mode(IM_REMOVE) ) {
        $Hmp->remove();    # ignore errors
    }
    else {
        log_msg( LL_ERROR, "Bad mode in HMP processing" );
        return;
    }
    log_msg( LL_VERBOSE, "XMS HMP subsystem processing completed" );
    return 1;
}

#
# General Init
#
sub init_data {

    my $error = 0;
    print $ConFd "Initializing...";

    my $save_level = $Xms_Log_Level;
    $Xms_Log_Level = LL_NONE;

    {    # new block
        if ($Distro_ID) { log_msg( LL_VERBOSE, "OS Version: $Distro_ID" ); }

        # ISO installation does not have yum
        if ( !is_yum_setup() and !is_install_mode(IM_REMOVE) ) {
            log_msg( LL_WARNING, "Yum repositories do not appear to be configured on this system." );
            log_msg( LL_WARNING, "Required OS prerequisite packages may require manual installation" );

        }

        log_msg( LL_VERBOSE, 'SELINUX ', is_selinux_enforcing() ? 'is' : 'is not', ' enforcing' );

        # ignore distribution files if removing
        if ( is_install_mode(IM_REMOVE) ) {
            $Xms_Pkg_Dir = '';
        }
        else {
            # make sure we have at least enough space to initialize ourselves
            # actual installation/update requirements are verified later
            my $freespace = get_disk_free_space();
            if ( $freespace >= 0 and $freespace < 150 ) {
                log_msg( LL_ERROR, "Insufficient free disk space available ($freespace MB) for initialization." );
                $error = E_GEN_DISK_SPACE;
                last;
            }
        }

        # Init XMS core packages
        my $grp = PkgGrp->new( name          => 'XMS core',
                               no_post_upg   => 1,
                               no_check_ver  => 0,
                               file_required => 1
        );
        if ( !$grp or !$grp->init( $Xms_Pkg_Dir, @Pkgs_Xms_Components ) ) {
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        $grp->log_info();
        if ( !$grp->is_dist_ver_unique() ) {
            log_msg( LL_ERROR, $grp->name(), " components package versions in $Xms_Pkg_Dir do not match." );
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        $Xms_File_Version = $grp->group(0)->file_version();
        $Pkg_Groups{'core'} = $grp;

        # Init XMS support packages included in this XMS distribution
        $grp = PkgGrp->new( name          => 'XMS support',
                            no_post_upg   => 0,
                            no_check_ver  => 0,
                            file_required => 1
        );
        if ( !$grp or !$grp->init( $Xms_Pkg_Dir, @Pkgs_Support ) ) {
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        $grp->log_info();
        $Pkg_Groups{'support'} = $grp;

        # Hmp subystem packages
        $Hmp = Hmp->new();
        if ( !$Hmp or !$Hmp->init($Xms_Pkg_Dir) ) {
            log_msg( LL_ERROR, "Error initializing HMP subsystem packages" );
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }
        $Hmp->cli_telnet_port( $CmdLnOpt{'xms-cliport'} );
        $Hmp->rtp_address( $CmdLnOpt{'xms-rtpaddr'} );

        # Init the prerequisite OS packages requiring special treatment
        $grp = PkgGrp->new( name          => 'XMS special prerequisites',
                            no_post_upg   => 0,
                            no_check_ver  => 0,
                            file_required => 0
        );
        if ( !$grp or !$grp->init( $Xms_Pkg_Dir, @Pkgs_Distro_Special ) ) {
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        ( $CmdLnOpt{verbose} < LL_DEBUG ) or $grp->log_info();
        $Pkg_Groups{'prereq_special'} = $grp;

        # Init the prerequisite OS packages required by XMS
        # handle the libjpeg / libjpeg-turbo special case
        my $libjname;
        foreach my $pkg_name ( 'libjpeg', 'libjpeg-turbo' ) {
            my $pkg32 = $grp->get_package( $pkg_name . '.i686' );
            my $pkg64 = $grp->get_package( $pkg_name . '.x86_64' );

            if ( $pkg32->is_installed() or $pkg64->is_installed() ) {
                $libjname = $pkg_name . '.i686';
                last;
            }
        }
        if ( !$libjname ) {
            $libjname = 'libjpeg.i686';
            if ( $Distro_ID =~ /\b6\.([2-9])\b/ ) {
                if ( $1 >= 3 ) {
                    $libjname = 'libjpeg-turbo.i686';
                }
            }
            else { log_msg( LL_ERROR, "Can't detect OS Version" ); }
        }
        push( @Pkgs_Distro_Required, $libjname );
        log_msg( LL_VVERBOSE, 'Added ', $libjname, ' to OS preprequisites' );

        $grp = PkgGrp->new( name          => 'XMS prerequisites',
                            no_post_upg   => 0,
                            no_check_ver  => 0,
                            file_required => 0
        );
        if ( !$grp or !$grp->init( $Xms_Pkg_Dir, @Pkgs_Distro_Required ) ) {
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        $grp->log_info();
        $Pkg_Groups{'prereq'} = $grp;

        # Init the prerequisite OS packages incompatible with XMS
        $grp = PkgGrp->new( name          => 'XMS Incompatible',
                            no_post_upg   => 0,
                            no_check_ver  => 0,
                            file_required => 0
        );
        if ( !$grp or !$grp->init( $Xms_Pkg_Dir, @Pkgs_Distro_Incompatible ) ) {
            $error = E_GEN_DIST_CORRUPTED;
            last;
        }

        $grp->log_info();
        $Pkg_Groups{'prereq_incompatible'} = $grp;

        # Setup services

        foreach my $srvname (@OS_Service_Names) {
            my $srv = Srv->new( name => $srvname );
            if ($srv) { $OS_Services{$srvname} = $srv; }
            else {
                log_msg( LL_ERROR, "Can't create $srvname service" );
                $error = E_GEN_FAILED;
                last;
            }
        }

        foreach my $srvname ( keys %XMS_Service_Names ) {
            my $srv = Srv->new( name => $srvname, description => $XMS_Service_Names{$srvname} );
            if ($srv) {
                $XMS_Services{$srvname} = $srv;
            }
            else {
                log_msg( LL_ERROR, "Can't create $srvname service" );
                $error = E_GEN_FAILED;
                last;
            }
        }

        $Nodecontroller = $XMS_Services{'nodecontroller'};

        # Verify existing XMS installation
        if ( !verify_xms_installation() ) {
            if ( !is_install_mode(IM_REMOVE) ) {
                log_msg( LL_ERROR, "A partial XMS installation was detected. Run $0 -r to remove" );
                $error = E_GEN_XMS_CORRUPTED;
                last;
            }
        }

    }

    $Xms_Log_Level = $save_level;
    if ($error) {
        print $ConFd "Failed\n";
        log_print_con(qr/[12]/);
        log_msg( LL_ERROR, "Initialization failed." );
        $Errno = $error;
        return;
    }
    else {
        print $ConFd "Done.\n";
    }
    return 1;
}

sub exit_cleanup {
    my $exit_code = shift;

    log_close();
    exit $exit_code;
}

#
# very that existing installation is sane
#
sub verify_xms_installation {
    my $xms_pkg_groups_installed = 0;

    # get installed XMS version if any
    $Xms_Installed_Version = '';
    foreach my $pkg ( @{ $Pkg_Groups{'core'}->group() } ) {
        if ( $pkg->is_installed() ) {
            $Xms_Installed_Version = $pkg->inst_version();
            last;
        }
    }

    if ($Xms_Installed_Version) {
        log_msg( LL_VERBOSE, "Found a previous installation of XMS version $Xms_Installed_Version" );
        foreach my $grp ( $Pkg_Groups{'core'}, $Pkg_Groups{'support'} ) {
            my $status = '';
            my $diff   = '';
            if ( $grp->install_status() == 1 ) { $xms_pkg_groups_installed++; }
            elsif ( $grp->install_status() == -1 ) {
                if ( $Xms_Installed_Version eq $Xms_File_Version ) {
                    $status = 'partially ';
                }
                else {
                    $xms_pkg_groups_installed++;
                    $diff = ' (number of packages differs from this distribution)';
                }
            }
            else { $status = 'not '; }

            log_msg( LL_VERBOSE, $grp->name(), ' packages are ', $status, 'installed', $diff );
        }
    }

    # check for HMP component

    if ( $Hmp->is_installed() ) {
        $Xms_HMP_Installed_Version = $Hmp->inst_version();
        if ($Xms_HMP_Installed_Version) {
            log_msg( LL_VERBOSE, "XMS HMP subsystem ($Xms_HMP_Installed_Version) is installed" );
            $xms_pkg_groups_installed++;
        }
        else {
            log_msg( LL_ERROR, "Can't obtain HMP version" );
            return;
        }
    }
    else {
        log_msg( LL_VERBOSE, 'XMS HMP subsystem is not installed' );
    }

    if ( $xms_pkg_groups_installed == 3 ) {
        $Xms_Install_Status = XIS_INSTALLED;
    }
    elsif ( $xms_pkg_groups_installed > 0 ) {
        $Xms_Install_Status    = XIS_PARTIAL;
        $Xms_Installed_Version = '(Corrupted)';
        return;
    }
    else {
        $Xms_Install_Status = XIS_NOT_INSTALLED;
    }

    if ( is_xms_installed() ) {
        log_msg( LL_VERBOSE, 'XMS Services runtime status:' );
        log_msg( LL_VERBOSE, sprintf( "    %-35s %s", 'SERVICE NAME', 'STATUS' ) );

        foreach my $srv ( values %XMS_Services ) {
            log_msg( LL_VERBOSE, sprintf( "    %-35s %s", $srv->description(), $srv->is_running() ? 'running' : 'stopped' ) );
        }
    }
    return 1;
}

#
# Verify that the requested operation can proceed
#
sub validate_request {

    print $ConFd "\nCurrently installed XMS Version: ", $Xms_Installed_Version ? $Xms_Installed_Version : 'None', "\n\n";

    if ( is_install_mode(IM_UPDATE) and !is_xms_installed() ) {
        $Xms_Install_Mode = IM_INSTALL;
        log_msg( LL_VVERBOSE, "XMS is not installed, switching to install mode" );
    }

    if ( is_install_mode(IM_INSTALL) and is_xms_installed() ) {
        log_msg( LL_WARNING, "XMS is already installed. Use -u for upgrade." );
        return;
    }

    if ( is_install_mode(IM_UPDATE) ) {
        if ( xms_ver_cmp( $Xms_File_Version, $Xms_Installed_Version ) == 0 ) {
            log_msg( LL_INFO, "XMS version $Xms_Installed_Version is already installed" );
            $Errno = E_UPG_SAME_VERSION;
            return;
        }
        elsif ( xms_ver_cmp( $Xms_File_Version, $Xms_Installed_Version ) < 0 ) {
            log_msg( LL_VVERBOSE, "Upgrade from version $Xms_Installed_Version to version $Xms_File_Version" );
            log_msg( LL_ERROR,    "Downgrading is not supported" );
            $Errno = E_UPG_NO_DOWNGRADE;
            return;
        }
    }

    if ( !is_install_mode(IM_REMOVE) ) {

        # check if we are not on CentOS, yum is not setup and there are missing prerequisites
        if ( !is_distro('CentOS') and !is_yum_setup() ) {
            my $grp = $Pkg_Groups{'prereq'};
            if ( $grp->get_not_installed() ) {
                ::log_msg( ::LL_ERROR, 'The following required OS prerequisite packages are not installed:' );
                $grp->log_not_installed();
                ::log_msg( ::LL_INFO,
                           'This script can automatically install prerequisites if Yum is configured with standard repositories for your OS version.' );
                ::log_msg( ::LL_INFO,
                      'Configure the online repositories or a DVD/ISO repository for your OS version or install the missing packages manually and try again.' );
                return;
            }
        }

        #before starting requested operation , check for incompatible RPM packages
        log_msg( LL_VVERBOSE, 'Verifying prerequisite package compatiblity with installed OS packages' );
        my $grp   = $Pkg_Groups{'prereq_incompatible'};
        my $error = 0;
        foreach my $ipkg ( @{ $grp->group() } ) {
            if ( $ipkg->is_installed() ) {
                log_msg( LL_ERROR, 'The installed 64-bit ', $ipkg->name(), ' package is incompatible with the 32-bit ', $ipkg->name(), ' required by XMS' );
                $error = E_GEN_PREREQ_NOT_COMPAT;
            }
        }

        if ($error) {
            log_msg( LL_WARNING, 'Uninstall incompatible 64-bit packages before installing XMS' );
            $Errno = $error;
            return;
        }
        else { log_msg( LL_VVERBOSE, 'Prerequisite package compatiblity verification passed' ); }
    }
    return 1;
}

#
# Verify that we have enough disk space to install or upgrade
#   - required space = incoming pkg size - already installed size (if any);
#   - prerequisite size is estimated as not all prerequisistes are included in this distribution
#   - returns true if we have enough space or user overrides
#

sub check_disk_space {
    use POSIX qw(ceil);
    my @pkg_groups     = values %Pkg_Groups;
    my $file_size      = 0;
    my $installed_size = 0;
    my $prereq_size    = 0;

    if ( !is_install_mode( IM_UPDATE | IM_INSTALL ) ) {
        return 1;
    }

    foreach my $grp (@pkg_groups) {
        next if $grp->name() eq 'XMS prerequisites';
        $file_size      += $grp->get_pkgfile_size();
        $installed_size += $grp->get_pkginst_size();
    }

    if ( !$Hmp->is_installed() or $Hmp->needs_update() ) {
        $file_size += $Hmp->get_pkgfile_size();

        # ignore the installed size for HMP because HMP install script does not account for it when checking disk space.
    }

    $file_size      = ceil( $file_size /      ( 1024 * 1024 ) );
    $installed_size = ceil( $installed_size / ( 1024 * 1024 ) );

    if ( $Pkg_Groups{'prereq'}->install_status() != 1 ) { $prereq_size = 200; }    # MB max estimate

    if ( ( my $freespace = get_disk_free_space() ) >= 0 ) {

        log_msg( LL_DEBUG, "Disk space (MB): xms+hmp req: $file_size, xms inst size: $installed_size, missing prereq: $prereq_size, available: ", $freespace );
        my $total_size = $file_size - $installed_size;
        if ( $total_size < 0 ) { $total_size = 0; }
        if ( $total_size + $prereq_size > $freespace ) {
            my $prompt = "\nThe requested operation will require:\n";
            if ($total_size)  { $prompt .= '  - up to ' . $total_size . "M of additional disk space for XMS files\n"; }
            if ($prereq_size) { $prompt .= "  - up to an additional " . $prereq_size . "M for any missing prerequisites\n"; }
            $prompt .= "The total required size (" . ( $total_size + $prereq_size ) . "M) exeeds the available space (" . $freespace . "M).\nAbort operation ?";
            my $response = ask_user( $prompt, 'yn', 'y' );
            if ( $response eq 'y' ) {
                return 0;
            }
            else {
                log_msg( LL_WARNING, "Operation proceeding with low disk space condition (user requested)" );
            }
        }
    }
    return 1;
}

#
# Compare XMS versions
#
sub xms_ver_cmp {

    # version formats vary.  Possibilities are :
    #     <maj>.<min>.<svn rev>
    #     <maj>.<min>.<extra>.<svn rev>
    #     <"trunk">.<svn rev>
    #
    # <extra> is always ignored
    # any dev version ("trunk") causes a comparison of the revision only
    my ( @av1, @av2 );
    my $start = 0;
    foreach my $ar ( \@av1, \@av2 ) {
        my ( $maj, $min, $extra, $rev ) = split( '\.', shift @_ );

        defined($maj) or return 1;
        if ( $maj eq 'trunk' ) {
            $rev   = $min;
            $start = 2;
        }
        elsif ( !defined($rev) ) {
            $rev = $extra;
        }
        @{$ar} = ( $maj, $min, $rev );
    }

    foreach my $ind ( $start .. $#av1 ) {
        my $rc = $av1[$ind] <=> $av2[$ind];
        return $rc unless $rc == 0;
    }
    return 0;
}

#####################
# Packages
#####################

#
# Service management
#
{

    package Srv;

    sub start {
        my $self = shift;
        if ( $self->is_running() ) {
            return 1;
        }
        return _execserv( $self, 'start' );
    }

    sub stop {
        my $self = shift;
        if ( !$self->is_running() ) {
            return 1;
        }
        return _execserv( $self, 'stop' );

    }

    sub kill {
        my $self = shift;
        if ( !::exec_log_stderr( '/etc/redhat-lsb/lsb_killproc', $self->name() ) ) {
            ::log_msg( ::LL_WARNING, $self->name() . ' service kill failed' );
            return;
        }
        return 1;
    }

    sub reload {
        my $self = shift;
        return _execserv( $self, 'reload' );
    }

    sub add {
        my $self = shift;
        return _execchk( $self, '--add ' . $self->name(), 'add' );
    }

    sub remove {
        my $self = shift;
        return ( !is_added($self) or _execchk( $self, '--del ' . $self->name(), 'remove' ) );
    }

    sub enable {
        my $self = shift;
        return _execchk( $self, $self->name() . ' on', 'enable' );
    }

    sub disable {
        my $self = shift;
        return _execchk( $self, $self->name() . ' off', 'disable' );
    }

    sub is_enabled {
        my $self = shift;
        return _get_chk_status( $self->name(), 'on' );
    }

    sub is_added {
        my $self = shift;
        return _get_chk_status( $self->name(), 'on|off' );
    }

    sub is_running {
        my $self   = shift;
        my $name   = $self->name();
        my $status = `/etc/redhat-lsb/lsb_pidofproc $name`;
        return $status ? 1 : 0;
    }

    sub _get_chk_status {
        my $srv_name   = shift;
        my $srv_status = shift;
        my $line       = `chkconfig --list $srv_name 2> /dev/null`;

        if ( ${^CHILD_ERROR_NATIVE} == 0 ) {
            if ( $line =~ /($srv_name).+[345]:($srv_status)/ ) {
                return 1;
            }
        }
        elsif ( ${^CHILD_ERROR_NATIVE} < 0 ) {
            ::log_msg( ::LL_ERROR, "Can't exec chkconfig for $srv_name service" );
        }

        return;
    }

    sub _execchk {
        my ( $self, $prm, $msg ) = @_;

        if ( !::exec_log_stderr( 'chkconfig', $prm ) ) {
            ::log_msg( ::LL_ERROR, "chkconfig $msg ", $self->name(), " service failed" );
            return;
        }
        else {
            ::log_msg( ::LL_VVERBOSE, "chkconfig $msg ", $self->name(), " service completed" );
            return 1;
        }
    }

    sub _execserv {
        my ( $self, $prm ) = @_;

        if ( !::exec_log_stderr( 'service ', $self->name(), $prm ) ) {    #pass
            ::log_msg( ::LL_ERROR, $self->name() . ' service ' . $prm . ' failed' );
            return;
        }
        else {
            ::log_msg( ::LL_VERBOSE, $self->name() . ' service ' . $prm . ' completed' );
            return 1;
        }
    }
}

#
# OS Package
#
{

    package Pkg;

    # Install this package
    sub install {
        return _install_pkg(@_);
    }

    # Install this package without docs
    sub install_exclude_docs {
        return _install_pkg( @_, '--excludedocs' );
    }

    # Perform the installation
    sub _install_pkg {
        my $self  = shift;
        my @extra = @_;
        if ( !$self->is_installed() ) {
            if ( $self->filename() ) {
                ::log_msg( ::LL_VERBOSE, 'Installing package: ', $self->name(), '.', $self->arch() );
                if ( !::exec_log_stderr( 'rpm', @extra, '-i --nosignature -p ', $self->path() ) ) {
                    return 0;
                }
            }
            else {
                ::log_msg( ::LL_ERROR, 'No filename for package ', $self->name(), '.', $self->arch() );
                return 0;
            }
        }
        else {
            ::log_msg( ::LL_VERBOSE, 'Package ', $self->name(), '.', $self->arch(), ' is already installed' );
        }
        return 1;
    }
}

#
# Package Group Management
#
{

    package PkgGrp;

    my $format;
    my $LL;

    sub init {
        my $self      = shift;
        my $pdir      = shift;
        my @pkg_names = @_;
        my @pkgl      = _init_pkg_info( $pdir, @pkg_names );

        if ( scalar @pkgl != scalar @pkg_names ) {
            ::log_msg( ::LL_ERROR, $self->name(), ' packages expected: ', scalar @pkg_names, '  packages found: ', scalar @pkgl );
            return;
        }

        if ( $pdir and $self->file_required ) {
            foreach my $pkg (@pkgl) {
                if ( !$pkg->filename() ) {
                    ::log_msg( ::LL_ERROR, 'rpm file for package ', $pkg->name(), '.', $pkg->arch(), ' is not found in ', $pdir );
                    return;
                }
            }
        }

        $self->group( \@pkgl );
        $format = "   %-25s %-8s %-14s %-10s";
        $LL     = ::LL_VERBOSE;
        return 1;
    }

    sub log_info {
        my $self = shift;
        ::log_msg( $LL, $self->name(), ' package information' );
        ::log_msg( $LL, sprintf( $format, 'NAME', 'ARCH', 'INSTALLED VER', 'DIST VER' ) );
        my $pkgi = $self->group;
        foreach (@$pkgi) {
            ::log_msg( $LL,
                       sprintf( $format,
                                $_->name(), $_->arch(),
                                $_->inst_version() ? $_->inst_version() : 'not installed', $_->file_version() ? $_->file_version() : 'N/A',
                       )
            );
        }
    }

    # log packages that are not installed
    sub log_not_installed {
        my $self = shift;
        my @missing_packages;

        #$self->refresh_status();
        if ( @missing_packages = $self->get_not_installed() ) {
            ::log_msg( ::LL_INFO, sprintf( "    %-20s %s", 'PACKAGE', 'ARCH' ) );
            foreach my $pkg (@missing_packages) {
                ::log_msg( ::LL_INFO, sprintf( "    %-20s %s", $pkg->name(), $pkg->arch() ) );
            }
        }

        return 1;
    }

    sub is_dist_ver_unique {
        my $self     = shift;
        my $file_ver = $self->group(0)->file_version();

        if ( scalar @{ $self->group } != grep { $_->file_version() eq $file_ver } @{ $self->group } ) {
            return;
        }
        return 1;
    }

    sub update {
        my $self = shift;
        my $rc;
        my $extra_param = $self->no_post_upg ? '--nopost ' : '';

        if ( $self->no_check_ver ) {
            $extra_param .= ' --oldpackage';
        }
        ::log_msg( ::LL_VERBOSE, 'Updating ', $self->name(), ' packages ' );
        if ( ( $rc = _update_packages( $extra_param, @{ $self->group } ) ) < 0 ) {
            ::log_msg( ::LL_ERROR, 'Error Updating ', $self->name(), ' packages' );
            return;
        }
        else {
            ::log_msg( ::LL_VERBOSE, "$rc ", $self->name(), ' packages needed updating' );
        }

        # Incoming version may contain additional packages
        if ( install_status($self) != 1 ) {
            install($self) or return;
        }
        return 1;
    }

    # is the entire group installed ?
    sub install_status {
        my $self = shift;
        my $pkg_cnt = grep { $_->is_installed() } @{ $self->group };
        if ( $pkg_cnt == scalar @{ $self->group } ) {
            return 1;
        }
        elsif ($pkg_cnt) {

            #partial installation
            return -1;
        }
        return 0;
    }

    sub get_not_installed {
        my $self             = shift;
        my @missing_packages = ();

        foreach my $pkg ( @{ $self->group() } ) {
            next unless !$pkg->is_installed();
            push( @missing_packages, $pkg );
        }
        return @missing_packages;
    }

    sub get_package {
        my $self = shift;
        if (@_) {
            my $pkg_full_name = shift;
            my ( $name, $arch ) = split( '\.', $pkg_full_name, 2 );
            foreach my $pkg ( @{ $self->group() } ) {
                next unless $pkg->name() eq $name and $pkg->arch() eq $arch;
                return $pkg;
            }
        }
        else {
            ::log_msg( ::LL_ERROR, 'missing package name in PkgGrp::get_package' );
        }
        return;
    }

    sub add_package {
        my $self = shift;
        my $pkg  = shift;
        if ($pkg) {
            push( @{ $self->group() }, $pkg );
            return 1;
        }
        else {
            ::log_msg( ::LL_ERROR, 'missing package reference in PkgGrp::add_package' );
        }
        return;
    }

    sub install {
        my $self = shift;

        ::log_msg( ::LL_VERBOSE, 'Installing ', $self->name, ' packages' );
        my $rc = _install_pkgs($self);
        if ( $rc < 0 ) {
            ::log_msg( ::LL_ERROR, 'Error Installing ', $self->name(), ' packages' );
            return 0;
        }
        else {
            ::log_msg( ::LL_VERBOSE, "$rc ", $self->name(), 'packages needed installing' );
            return 1;
        }

    }

    sub install_from_repos {
        my $self = shift;
        my $rc   = 0;
        ::log_msg( ::LL_VERBOSE, 'Installing ', $self->name, ' packages from repositories' );
        if ( ::is_yum_setup() ) {
            $rc = _install_pkgs_deps($self);
            if ( $rc < 0 ) {
                ::log_msg( ::LL_VERBOSE, 'Installation of ', $self->name, ' packages from repositories is incomplete' );
                return 0;
            }
        }
        else {
            ::log_msg( ::LL_VERBOSE, "Can't install ", $self->name, ' packages from repositories: no system repositories configured' );
            return 0;
        }

        ::log_msg( ::LL_VERBOSE, "$rc ", $self->name(), 'packages needed installing' );
        return 1;
    }

    sub remove {
        my $self = shift;

        my @pkgs = grep { $_->is_installed() } @{ $self->group };

        if ( scalar @pkgs ) {
            ::log_msg( ::LL_INFO, 'Removing ', scalar @pkgs, ' ', $self->name(), ' packages' );
            if ( !_remove_packages(@pkgs) ) {
                ::log_msg( ::LL_ERROR, 'Failed to remove ', $self->name(), ' packages' );
                return;
            }
        }
        else {
            ::log_msg( ::LL_INFO, $self->name(), ' packages are not installed' );
        }
        return 1;
    }

    sub refresh_status {
        my $self = shift;
        _check_installed_pkgs( @{ $self->group } );
        return 1;
    }

    # returns the total size (bytes) of packages in the group for which we supply
    # the package

    sub get_pkgfile_size {
        my $self       = shift;
        my $total_size = 0;
        foreach my $pkg ( @{ $self->group } ) {
            $total_size += $pkg->file_size();
        }
        return $total_size;
    }

    # returns the total size (bytes) of the package version currently installed
    sub get_pkginst_size {
        my $self       = shift;
        my $total_size = 0;
        foreach my $pkg ( @{ $self->group } ) {
            $total_size += $pkg->inst_size();
        }
        return $total_size;
    }

    sub num_packages {
        my $self = shift;
        return scalar @{ $self->group };
    }

    sub _install_pkgs_deps {
        my $self             = shift;
        my @pkg_names        = ();
        my @required_updates = ();

        foreach my $pkg ( @{ $self->group } ) {
            next if $pkg->is_installed();

            # for the case where a i686 package is being
            #installed, check if a x86_64 version of the same package is already
            #installed and add it to the list of updates to perform before
            #installing the i686 version to avoid the "Protected multilib"
            #error when i686 and x86_64 versions don't match.

            if ( $pkg->arch() =~ /i[36]86/ ) {
                push( @required_updates, $pkg->name . '.' . 'x86_64' );
            }

            push( @pkg_names, join( '.', $pkg->name(), $pkg->arch() ) );

        }

        if ( scalar @pkg_names ) {

            #run an update so the existing x86_64 versions before installing the i686 version
            if ( scalar @required_updates ) {
                ::log_msg( ::LL_VVERBOSE, 'Verifying updates for x86_64 packages before installing matching i686 version:' );
                foreach my $pname (@required_updates) {
                    ::log_msg( ::LL_VVERBOSE, "    $pname" );
                }

                if ( !::exec_log_stderr( 'yum', '-y -q update', @required_updates ) ) {
                    ::log_msg( ::LL_ERROR, "x86_64 pkg updates failed" );
                    return -1;
                }
                else {
                    ::log_msg( ::LL_VVERBOSE, "Verified updates for ", scalar @required_updates, " x86_64 packages before installing matching i686 versions", );
                }
            }

            ::log_msg( ::LL_VVERBOSE, 'Installing packages:' );
            foreach my $pname (@pkg_names) {
                ::log_msg( ::LL_VVERBOSE, "    $pname" );
            }
            if ( !::exec_log_stderr( 'yum', ' -y -q  install', @pkg_names ) ) {
                return -1;
            }

            # verify that all packages are installed
            refresh_status($self);
            if ( my @missing = get_not_installed($self) ) {
                ::log_msg( ::LL_VERBOSE, 'The following ', $self->name, ' packages could not be installed from the repositories:' );
                foreach my $pkg (@missing) {
                    ::log_msg( ::LL_VERBOSE, sprintf( "    %-20s %s", $pkg->name(), $pkg->arch() ) );
                }
                return -1;
            }
        }
        else {
            ::log_msg( ::LL_VERBOSE, "No packages to install" );
        }
        return scalar @pkg_names;
    }

    sub _install_pkgs {
        my $self      = shift;
        my @pkg_names = ();

        foreach my $pkg ( @{ $self->group } ) {
            next if $pkg->is_installed();

            if ( $pkg->filename() ) {
                push( @pkg_names, $pkg->path() );
                ::log_msg( ::LL_VERBOSE, sprintf( "    %-20s %s", $pkg->name(), $pkg->arch() ) );
            }
            else {
                ::log_msg( ::LL_ERROR, "No filename for package ", $pkg->name() );
                return -1;
            }
        }

        if ( scalar @pkg_names ) {
            if ( !::exec_log_stderr( 'rpm', '-i --nosignature -p ', @pkg_names ) ) {

                # error(s) occured duing rpm installation
                refresh_status($self);
                if ( my @missing = get_not_installed($self) ) {
                    ::log_msg( ::LL_ERROR, 'The following ', $self->name, ' packages remain not installed:' );
                    foreach my $pkg (@missing) {
                        ::log_msg( ::LL_ERROR, sprintf( "    %-20s %s", $pkg->name(), $pkg->arch() ) );
                    }
                }
                ::log_msg( ::LL_INFO, 'Resolve the above error(s) and try again' );
                return -1;
            }
        }
        return scalar @pkg_names;
    }

    sub _init_pkg_info {
        my $pkg_dir  = shift;
        my @pkg_list = sort @_;
        my $dh;

        my @pkg_files = ();
        my @pkg_info  = ();

        my %supplied_packages = _create_pkg_map($pkg_dir);

        foreach my $pkg_name (@pkg_list) {
            my ( $name, $arch ) = split( '\.', $pkg_name, 2 );
            $arch or $arch = 'x86_64';
            my $pkg = $supplied_packages{ $name . '.' . $arch };
            if ( !$pkg ) {
                $pkg = Pkg->new( name         => $name,
                                 arch         => $arch,
                                 filename     => '',
                                 path         => '',
                                 file_version => '',
                                 file_release => '',
                                 file_size    => 0,
                                 inst_size    => 0,
                                 is_installed => 0
                );
            }
            push( @pkg_info, $pkg );
        }

        # check if any of these are installed
        _check_installed_pkgs(@pkg_info);

        return @pkg_info;
    }

    sub _create_pkg_map {
        my $pkg_dir      = shift;
        my %name2pkginfo = ();

        my @pkg_files      = ();
        my @pkg_info       = ();
        my @pkg_file_paths = ();

        if ( !$pkg_dir ) {
            return %name2pkginfo;
        }

        # get list of rpms from the pkg dir
        my $pwd = ::cwd();

        if ( chdir($pkg_dir) ) {
            @pkg_files = sort glob("*.rpm");
        }
        else {
            ::log_msg( ::LL_ERROR, "Can't open package dir $pkg_dir : $!" );
            return %name2pkginfo;
        }
        chdir($pwd);

        # build pkg list
        foreach my $pkg_file_name (@pkg_files) {
            push( @pkg_file_paths, $pkg_dir . '/' . $pkg_file_name );
        }

        # get tag info from files
        if ( scalar @pkg_file_paths ) {
            my $bin = `which rpm`;
            chomp($bin);

            my $cmd = join( ' ', $bin, '-q --queryformat \'%{NAME}|%{VERSION}|%{ARCH}|%{RELEASE}|%{SIZE}\n\'', ' -p', @pkg_file_paths, '2> /dev/null' );

            if ( -x $bin ) {
                open( my $outp, '-|', "$cmd " );
                my $i = 0;
                foreach my $pkgNV (<$outp>) {
                    chomp $pkgNV;
                    my ( $name, $ver, $ar, $rel, $size ) = split( /\|/, $pkgNV );
                    my $pkg = Pkg->new( name => $name, arch => $ar, file_size => $size, inst_size => 0, file_version => $ver, file_release => $rel );
                    $pkg->path( shift @pkg_file_paths );
                    $pkg->filename( shift @pkg_files );
                    $name2pkginfo{ $name . '.' . $ar } = $pkg;
                }
                close($outp);
            }
            else {
                ::log_msg( ::LL_ERROR, "Can't locate rpm utility" );
            }
        }
        return %name2pkginfo;
    }

    sub _update_packages {
        my $extra_param = shift;
        my @pkg_info    = @_;
        my @pkg_names   = ();

        foreach my $pkg (@pkg_info) {
            if ( $pkg->filename() ) {
                if ( $pkg->is_installed() ) {
                    if ( $pkg->inst_version() ne $pkg->file_version() ) {
                        push( @pkg_names, $pkg->path() );
                    }
                }
                else {
                    ::log_msg( ::LL_VVERBOSE, "Package: ", $pkg->name(), " requires installation" );
                }
            }
            else { ::log_msg( ::LL_ERROR, "Can't update package with missing filename" ) }
        }

        if ( scalar @pkg_names ) {
            if ( !::exec_log_stderr( 'rpm', '-U ', $extra_param, ' --nosignature -p ', @pkg_names ) ) {
                return -1;
            }
        }
        return scalar @pkg_names;
    }

    sub _remove_packages {
        my @pkg_info = @_;

        my @pkg_files = ();
        foreach my $pkg (@pkg_info) {
            next unless $pkg->is_installed();
            push( @pkg_files, $pkg->name() . '.' . $pkg->arch() );
        }

        if ( scalar @pkg_files and !::exec_log_stderr( 'rpm', '-e', @pkg_files ) ) {
            return;
        }

        return 1;
    }

    sub _check_installed_pkgs {

        my @pkg_info = @_;
        my %name2pkginfo;

        my $pkg_reg = join '|', map { quotemeta( join( '.', $_->name(), $_->arch() ) ) } @pkg_info;
        my @pkg_names = ();

        foreach my $pkg (@pkg_info) {
            $name2pkginfo{ $pkg->name() . '.' . $pkg->arch() } = $pkg;
        }

        my $bin = `which rpm`;
        chomp $bin;
        my $cmd = join( ' ', $bin, '-q --queryformat \'%{NAME}.%{ARCH} %{VERSION} %{RELEASE} %{SIZE} \n\'', keys %name2pkginfo, '2> /dev/null' );

        if ( -x $bin ) {
            open( my $outp, '-|', "$cmd " );
            foreach my $line (<$outp>) {
                if ( $line =~ /^($pkg_reg)\b\s(.+?)\s(.+)\s(.+)/ ) {
                    ( $name2pkginfo{$1} )->is_installed(1);
                    ( $name2pkginfo{$1} )->inst_version($2);
                    ( $name2pkginfo{$1} )->inst_release($3);
                    ( $name2pkginfo{$1} )->inst_size($4);
                }
            }
            close($outp);
        }
        else {
            ::log_msg( ::LL_ERROR, "Can't locate rpm utility" );
        }
        return 0;
    }
}

################################################
# Config file
################################################
{

    package CfgFile;

    use constant { DEFAULT_SECTION            => '__NOSECT1ON__',
                   KEY_SECTION_PARAM_SEQUENCE => '__CFGF_PARAM_SEQ__',
                   KEY_SECTION_COMMENTS       => '__CFGF_SECTION_CMMNTS__',
                   KEY_PARAM_COMMENTS         => '__CFGF_PARAM_CMMNTS__',
                   KEY_TRAILING_COMMENTS      => '__CFGF_TRAILING_CMNTS__',
    };

    #use Data::Dumper;

    $CfgFile::_section_regx   = qr/^\s*\[\s*([\w\-]+)\s*\]/;
    $CfgFile::_key_value_regx = qr/^\s*([\w\-]+)\s*=\s*(.+?)\s*$/;

    sub new {
        my $classname = shift;
        my $self = { _file       => '',
                     _lines      => [],
                     _cfh        => undef,
                     _cmmnt_char => ';',
                     _modified   => 0,
                     _sections   => {},
                     _sec_seq    => [],
                     _meta_data  => {},
        };

        bless( $self, $classname );
        if ( $self->_init(@_) ) {
            return $self;
        }
    }

    sub merge {
        ::log_msg( ::LL_DEBUG, ( caller(0) )[3] );
    }

    sub _init {
        my $self  = shift;
        my %parms = @_;

        if ( defined $parms{file} ) {
            $self->{_file} = delete $parms{file};
            ::log_msg( ::LL_DEBUG, 'CfgFile name: ', $self->{_file} );
        }

        if ( defined $parms{comment_char} ) {
            $self->{_cmmnt_char} = delete $parms{_cmmnt_char};
            ::log_msg( ::LL_DEBUG, 'CfgFile comment char: ', $self->{_cmmnt_char} );
        }

        foreach my $leftover ( keys %parms ) {
            ::log_msg( ::LL_WARNING, "CfgFile: ignoring unkown parameter: $leftover" );
        }

        return $self->_load_file();
    }

    sub _load_file {
        my $self = shift;
        my $cfgh;
        my $cmnt          = $self->{_cmmnt_char};
        my $curr_section  = DEFAULT_SECTION;
        my @comment_lines = ();

        if ( !open( $cfgh, "<", $self->{_file} ) ) {
            ::log_msg( ::LL_ERROR, ( caller(0) )[3], ": can't open ", $self->{_file}, ": $!" );
            return;
        }

        $self->_add_section(DEFAULT_SECTION);
        while ( my $line = <$cfgh> ) {
            if ( $line =~ $CfgFile::_section_regx ) {
                if ( $curr_section ne $1 ) {
                    $curr_section = $1;
                    $self->_add_section( $1, @comment_lines );
                    @comment_lines = ();
                }
            }
            elsif ( $line =~ $CfgFile::_key_value_regx ) {
                $self->_add_value( $curr_section, $1, $2, @comment_lines );
                @comment_lines = ();
            }
            else {
                push( @comment_lines, $line );
            }
            push( @{ $self->{_lines} }, $line );
        }

        $self->{_meta_data}{CfgFile::DEFAULT_SECTION}{CfgFile::KEY_TRAILING_COMMENTS} = [@comment_lines];

        close($cfgh);

        #::log_msg( ::LL_DEBUG, ( caller(0) )[3], ' ', Dumper($self) );
        return 1;
    }

    sub write_file {
        my $self = shift;
        my ($filename) = @_ ? @_ : $self->{_file};

        if ( !open( $self->{_cfh}, ">", $filename ) ) {
            ::log_msg( ::LL_ERROR, ( caller(0) )[3], " : can't open ", $filename, " for writing: $!" );
            return;
        }

        #::log_msg( ::LL_DEBUG, ( caller(0) )[3], ' ', Dumper($self) );

        $self->_write_params(DEFAULT_SECTION);
        shift @{ $self->{_sec_seq} };
        foreach my $sect ( @{ $self->{_sec_seq} } ) {

            if ( scalar( $self->{_meta_data}{$sect}{CfgFile::KEY_SECTION_COMMENTS} ) ) {
                print { $self->{_cfh} } @{ $self->{_meta_data}{$sect}{CfgFile::KEY_SECTION_COMMENTS} };
            }

            print { $self->{_cfh} } "[$sect]\n";

            foreach my $key ( @{ $self->{_meta_data}{$sect}{CfgFile::KEY_SECTION_PARAM_SEQUENCE} } ) {
                next if !defined($key);
                if ( scalar( $self->{_meta_data}{$sect}{$key} ) ) {
                    print { $self->{_cfh} } @{ $self->{_meta_data}{$sect}{$key} };
                }
                ::log_msg( ::LL_DEBUG, "Writing key value in [$sect]: $key=", $self->{_sections}{$sect}{$key} );
                print { $self->{_cfh} } "$key = ", $self->{_sections}{$sect}{$key}, "\n";
            }
        }

        print { $self->{_cfh} } @{ $self->{_meta_data}{CfgFile::DEFAULT_SECTION}{CfgFile::KEY_TRAILING_COMMENTS} };
        close( $self->{_cfh} );
        $self->{_cfh} = undef;
        return 1;
    }

    sub get_value {
        my ( $self, $section, $key ) = @_;

        if ( exists( $self->{_sections}{$section}{$key} ) ) {
            return $self->{_sections}{$section}{$key};
        }
    }

    sub set_value {
        my $self = shift;
        my ( $section, $key, $value ) = @_;

        $self->_add_section($section);
        return $self->_add_value( $section, $key, $value );
    }

    sub delete_value {
        my $self = shift;
        my ( $section, $key ) = @_;

        if ( exists( $self->{_sections}{$section} ) ) {
            $self->{_modified} = 1;
            my $par_seq = $self->{_meta_data}{$section}{CfgFile::KEY_SECTION_PARAM_SEQUENCE};

            for ( my $i = 0 ; $i < scalar @$par_seq ; $i++ ) {
                if ( $par_seq->[$i] eq $key ) {
                    $par_seq->[$i] = undef;
                    last;
                }
            }

            delete( $self->{_meta_data}{$section}{$key} );
            return delete( $self->{_sections}{$section}{$key} );
        }
    }

    sub get_section_titles {
        my $self = shift;
        return @{ $self->{_sec_seq} };
    }

    sub get_section_values {
        my $self    = shift;
        my $section = shift;

        if ( exists( $self->{_sections}{$section} ) ) {
            my %export_section = %{ $self->{_sections}{$section} };

            return \%export_section;
        }
    }

    sub set_section_values {
        my ( $self, $section, $values ) = @_;

        if ( ref($values) eq "HASH" ) {
            $self->_add_section($section);
            map { $self->_add_value( $section, $_, $values->{$_} ) } keys %{$values};
            return 1;
        }
        else {
            ::log_msg( ::LL_ERROR, ( caller(0) )[3], ": values parameter is not a HASH" );
        }

    }

    sub _add_section {
        my $self           = shift;
        my $section        = shift;
        my @sec_cmnt_lines = @_ ? @_ : ("\n");

        if ( !exists( $self->{_sections}{$section} ) ) {
            $self->{_sections}{$section}  = {};
            $self->{_meta_data}{$section} = {};
            push( @{ $self->{_sec_seq} }, $section );
            $self->{_meta_data}{$section}{CfgFile::KEY_SECTION_PARAM_SEQUENCE} = [];
            $self->{_meta_data}{$section}{CfgFile::KEY_SECTION_COMMENTS}       = [@sec_cmnt_lines];
            $self->{_modified}                                                 = 1;
            return 1;
        }

    }

    sub _add_value {
        my $self             = shift;
        my $section          = shift;
        my $key              = shift;
        my $value            = shift;
        my @param_cmnt_lines = @_;

        if ( !( $key ~~ $self->{_meta_data}{$section}{CfgFile::KEY_SECTION_PARAM_SEQUENCE} ) ) {
            push( @{ $self->{_meta_data}{$section}{CfgFile::KEY_SECTION_PARAM_SEQUENCE} }, $key );
            $self->{_meta_data}{$section}{$key} = [];
        }
        $self->{_modified} = 1;
        $self->{_meta_data}{$section}{$key} = [@param_cmnt_lines] if scalar @param_cmnt_lines;
        return $self->{_sections}{$section}{$key} = $value;
    }

    sub _write_params {
        my ( $self, $sect ) = @_;

        foreach my $key ( @{ $self->{_meta_data}{$sect}{CfgFile::KEY_SECTION_PARAM_SEQUENCE} } ) {
            next if !defined($key);
            if ( scalar( $self->{_meta_data}{$sect}{$key} ) ) {
                print { $self->{_cfh} } @{ $self->{_meta_data}{$sect}{$key} };
            }
            print { $self->{_cfh} } "$key=", $self->{_sections}{$sect}{$key}, "\n";
        }
        return 1;
    }
}

#
# HMP subsystem
#
{

    package Hmp;

    use File::Find;

    sub Hmp::init {
        my $self = shift;

        $self->path(shift) if @_;

        # optional -- if path not supplied , only status and uninstall ops are available
        if ( $self->path ) {

            ::log_msg( ::LL_DEBUG, "HMP package path: ", $self->path );

            if ( !_open_archive($self) ) {
                return;
            }

            if ( !$self->dist_version( _get_version( $self->_tar_dir . '/buildinfo' ) ) ) {
                ::log_msg( ::LL_ERROR, "Error getting HMP version from distribution" );
                return;
            }
            ::log_msg( ::LL_DEBUG, 'HMP distribution Version: ', $self->dist_version );
        }
        else { $self->dist_version(''); }

        $self->_hmp_pkgs( PkgGrp->new( name => 'HMP Subsystem', no_post_upg => 0, no_check_ver => 0 ) );
        if (    !$self->_hmp_pkgs
             or !$self->_hmp_pkgs->init( defined( $self->_tar_dir ) ? $self->_tar_dir . '/redistributable-runtime' : '', @Pkgs_Hmp_Sybsystem ) )
        {
            return;
        }
        $self->_hmp_pkgs->log_info();

        $self->_media_pkgs( PkgGrp->new( name => 'HMP Media', no_post_upg => 0, no_check_ver => 0 ) );
        if (    !$self->_media_pkgs
             or !$self->_media_pkgs->init( defined( $self->_tar_dir ) ? $self->_tar_dir . '/media_server_prompts' : '', @Pkgs_Hmp_Media ) )
        {
            return;
        }

        $self->_media_pkgs->log_info();

        if ( -e '/usr/dialogic/cfg/buildinfo' ) {
            if ( !$self->inst_version( _get_version('/usr/dialogic/cfg/buildinfo') ) ) {
                ::log_msg( ::LL_ERROR, 'Corrupted (partially installed) HMP subsystem detected' );
                $self->inst_version('(Corrupted)');
            }
        }
        else {
            ::log_msg( ::LL_DEBUG, 'XMS HMP subsystem is not installed' );
        }
        return 1;
    }

    sub Hmp::install {
        my $self = shift;

        if ( $self->inst_version ) {
            ::log_msg( ::LL_INFO, 'XMS HMP subsystem version ', $self->inst_version, ' already installed' );
        }

        if ( !$self->dist_version ) {
            ::log_msg( ::LL_ERROR, 'HMP install : missing distribution package' );
            return;
        }

        ::log_msg( ::LL_INFO, 'Installing XMS HMP subsystem version ', $self->dist_version );

        if ( !_run_script($self) ) {
            ::log_msg( ::LL_ERROR, 'HMP components Installation failed. Remove and re-install XMS.' );
            return;
        }

        #install media server prompts
        if ( !$self->_media_pkgs->install() ) {
            ::log_msg( ::LL_ERROR, "Media Server Prompts installation failed. Remove and re-install XMS." );
            return;
        }

        # setup Hmp configuration files
        if ( !_configure($self) ) {
            ::log_msg( ::LL_ERROR, "XMS HMP subsystem post installation configuration failed. Remove and re-install XMS." );
            return;
        }

        # temporarily apply webrtc overlay
        if ( !_apply_webrtc_overlay($self) ) {
            ::log_msg( ::LL_WARNING, "XMS HMP webrtc overlay was not applied. Verify distribution contents." );
            return 1;
        }

        ::log_msg( ::LL_VERBOSE, "XMS HMP subsystem components installed successfully" );
        return 1;
    }

    sub Hmp::update {
        my $self = shift;

        if ( !$self->dist_version ) {
            ::log_msg( ::LL_ERROR, 'HMP update : missing distribution package' );
            return;
        }

        if ( !$self->is_installed() ) {
            ::log_msg( ::LL_ERROR, 'HMP update: HMP installation not found ' );
            return;
        }

        # 4.1.x is assumed
        my ( undef, undef, $ibuild ) = split( '\.', $self->inst_version );
        my ( undef, undef, $dbuild ) = split( '\.', $self->dist_version );
        if ( $ibuild >= $dbuild ) {
            ::log_msg( ::LL_VERBOSE, 'XMS HMP subsystem version ', $self->inst_version, ' is up to date' );

            # temporarily apply webrtc overlay
            if ( !_apply_webrtc_overlay($self) ) {
                ::log_msg( ::LL_WARNING, "XMS HMP webrtc overlay was not applied. Verify distribution contents." );
            }

            #setup telnet port if required
            $self->_setup_telnet_port();

            return 1;
        }

        ::log_msg( ::LL_VERBOSE, 'Updating XMS HMP subsystem version ', $self->inst_version, ' to ', $self->dist_version );

        # backup config files before updating
        find( \&_backup_conf, '/usr/dialogic/cfg' );

        if ( !_run_script($self) ) {
            ::log_msg( ::LL_ERROR, 'HMP components update failed. Remove and re-install XMS.' );
            return;
        }

        #restore backed up files
        find( \&_restore_conf, '/usr/dialogic/cfg' );

        #update media server prompts and setup configuration files
        if ( !$self->_media_pkgs->update() or !_configure($self) ) {
            ::log_msg( ::LL_ERROR, "XMS HMP subsystem update failed" );
            return;
        }

        # temporarily apply webrtc overlay
        if ( !_apply_webrtc_overlay($self) ) {
            ::log_msg( ::LL_WARNING, "XMS HMP webrtc overlay was not applied. Verify distribution contents." );
            return 1;
        }

        #setup telnet port if required
        $self->_setup_telnet_port();
        ::log_msg( ::LL_VERBOSE, "XMS HMP subsystem components updated successfully" );
        return 1;
    }

    sub Hmp::remove {
        my $self = shift;

        if ( !$self->_media_pkgs->remove() ) {
            ::log_msg( ::LL_ERROR, 'Failed to remove ', $self->_media_pkgs->name(), ' packages' );
        }

        if ( -e '/usr/dialogic/bin' ) {

            my $scr = '/usr/dialogic/bin/dlguninstall.sh';
            if ( -e $scr ) {
                ::log_msg( ::LL_INFO, 'Removing XMS HMP subsystem components version ', $self->inst_version );
                my $cwd = ::cwd();
                chdir('/usr/dialogic/bin');

                # save tty settings and install hmp
                my $tty_save = `stty -g`;
                if ( !::exec_log_stderr( 'bash', '-c', '". /etc/profile.d/ct_intel.sh; dlguninstall.sh --silent"' )
                     and -e '/usr/dialogic' )
                {
                    ::log_msg( ::LL_ERROR, "Error removing HMP subsystem" );
                    system("stty $tty_save");
                    chdir($cwd);
                    return;
                }
                else {
                    ::log_msg( ::LL_VERBOSE, "XMS HMP subsystem removed successfully" );
                }
                system("stty $tty_save");
                chdir($cwd);
            }
            else {
                ::log_msg( ::LL_ERROR, "Missing HMP uninstall script: $scr" );
                return;
            }
        }
        else {
            ::log_msg( ::LL_INFO, "XMS HMP subsystem is not installed" );
        }
        return 1;
    }

    sub Hmp::start {
        my $self = shift;

        if ( !::exec_log_stderr( 'bash', '-c', '". /etc/profile.d/ct_intel.sh; dlstart"' ) ) {
            ::log_msg( ::LL_ERROR, "Failed to start HMP" );
            return;
        }
        return 1;
    }

    sub Hmp::stop {
        my $self = shift;

        if ( !::exec_log_stderr( 'bash', '-c', '". /etc/profile.d/ct_intel.sh; dlstop"' ) ) {
            ::log_msg( ::LL_ERROR, "Failed to stop HMP" );
            return;
        }
        return 1;
    }

    sub Hmp::setup_default_lic {
        my $self             = shift;
        my $Lic_Setup_Script = '/usr/dialogic/bin/firstboot-setup';

        if ( -e $Lic_Setup_Script ) {
            if ( !::exec_log_stderr( 'expect', $Lic_Setup_Script ) ) {
                ::log_msg( ::LL_ERROR, "Failed to configure default license" );
                return;
            }
        }
        else {
            ::log_msg( ::LL_ERROR, "Can't configure default license: missing $Lic_Setup_Script" );
            return;
        }
        return 1;
    }

    sub Hmp::setup_rtp_addr {
        my $self = shift;
        my $addr = $self->rtp_address();

        my $rtp_addr_script = <<'END_EXP';
set username "root"
set password "public"
set host "127.0.0.1"
set port [exec grep CLI_LISTENER= /etc/init.d/ct_intel | cut -d= -f2]
set rtpipaddr [lindex $argv 0]

set timeout 30

if { $port == "" } {
    set port "23"
}

spawn telnet $host $port

expect_before eof {
    send_user "Failed to connect.\n"
    exit 1
}

expect -re "Login :" {
    send "$username\r"
}

expect -re "Password :" {
    send "$password\r"
}
   
expect {
    -re "Login :" {
        send_user "Login failed.\n"
        exit 1
    }
    -re "CLI> " {
        send "\r"
    }
}

if { $rtpipaddr!= "" } {
    expect {
        -re "CLI> $" {
            send "conf system hmp-rtp-address $rtpipaddr\r"
         }
    }
    
    expect {
       -re "updated" {
            send "quit\r"
       }

       -re "bad value" {
           send_user "Invalid IP address\n"
           send "quit\r"
           exit 1
      }
    }
}
exit 0
END_EXP

        if ($addr) {
            my $tef = File::Temp->new( EXLOCK => 0 );
            print $tef $rtp_addr_script;
            if ( !::exec_log_stderr( 'expect', "-f $tef", $addr ) ) {
                ::log_msg( ::LL_ERROR, "Failed to configure rtp address ($addr)" );
                return;
            }

            ::log_msg( ::LL_VERBOSE, "Configured RTP address ($addr)" );
        }
        return 1;
    }

    sub Hmp::get_pkgfile_size {
        my $self = shift;
        if ( defined( $self->_media_pkgs ) ) {
            return $self->_hmp_pkgs->get_pkgfile_size() + $self->_media_pkgs->get_pkgfile_size()    # + ((1024*1024) * 20);
        }
        return 0;
    }

    sub Hmp::get_pkginst_size {
        my $self = shift;
        if ( defined( $self->_media_pkgs ) ) {
            return $self->_hmp_pkgs->get_pkginst_size() + $self->_media_pkgs->get_pkginst_size();
        }
        return 0;
    }

    sub Hmp::is_installed {
        my $self = shift;
        return $self->inst_version;
    }

    sub Hmp::needs_update {
        my $self = shift;

        if ( !$self->dist_version or !$self->is_installed() ) {
            return;
        }

        # 4.1.x is assumed
        my ( undef, undef, $ibuild ) = split( '\.', $self->inst_version );
        my ( undef, undef, $dbuild ) = split( '\.', $self->dist_version );
        if ( $dbuild > $ibuild ) {
            return 1;
        }

        return;
    }

    sub Hmp::_backup_conf {
        my $fname = $File::Find::name;
        return unless $fname =~ m!.+?\.(conf|cfg|xml)$!;

        if ( !::copy( $fname, $fname . $Conf_File_Backup_Ext ) ) {
            ::log_msg( ::LL_ERROR, "Can't backup $fname: $!" );
        }
        else { ::log_msg( ::LL_VVERBOSE, "Backed up $fname to ", $fname, $Conf_File_Backup_Ext ); }
    }

    sub Hmp::_restore_conf {
        my $fname = $File::Find::name;
        if ( $fname =~ m!.+?\.(conf|cfg|xml)$! ) {
            if ( -e $fname . $Conf_File_Backup_Ext ) {
                if (     ::copy( $fname, $fname . '.' . $Xms_File_Version )
                     and ::copy( $fname . $Conf_File_Backup_Ext, $fname ) )
                {
                    ::log_msg( ::LL_VVERBOSE, "Restored $fname after upgrade" );
                    unlink( $fname . $Conf_File_Backup_Ext );
                }
                else { ::log_msg( ::LL_ERROR, "Can't restore $fname: $!" ); }
            }
            else { ::log_msg( ::LL_DEBUG, "New (post upgrade) configuration file found: $fname" ); }
        }
    }

    sub Hmp::_run_script {
        my $self = shift;
        my $pwd  = ::cwd();

        # HMP install script has to be executed from its cwd
        if ( !chdir( $self->_tar_dir . '/redistributable-runtime' ) ) {
            ::log_msg( ::LL_ERROR, 'Hmp install: Error changing directory to ', $self->_tar_dir . "/redistributable-runtime: $!" );
            return;
        }

        # save tty settings and install hmp
        my $tty_save = `stty -g`;
        if ( !::exec_log_stderr( './install.sh', '--silent', 'lsb-dialogic-hmp41-hmp' ) ) {
            system("stty $tty_save");
            chdir($pwd);
            return;
        }

        #restore tty settings and cwd
        system("stty $tty_save");
        chdir($pwd);
        return 1;
    }

    sub Hmp::_configure {
        my $self = shift;

        # RTP latency mods

        my $ucfg_file = '/usr/dialogic/data/Hmp.Uconfig';
        if ( $self->inst_version ) {

            #if there was an installed version we ae upgrading so backup the current
            #file and replace with the incoming version
            my $bkp = $ucfg_file . ".$Xms_Installed_Version";
            if ( ::copy( $ucfg_file, $bkp ) ) {
                ::log_msg( ::LL_VERBOSE, "Backed up existing Hmp.Uconfig to $bkp. Merge if previously manually modified" );
            }
            else {
                ::log_msg( ::LL_ERROR, "Failed to backup Hmp.Uconfig to $bkp: $!" );

                #not fatal
            }
        }

        if ( ::copy( $self->path . '/Hmp.Uconfig', $ucfg_file ) ) {
            ::log_msg( ::LL_VERBOSE, "Hmp.Uconfig setup OK" );
        }
        else {
            ::log_msg( ::LL_ERROR, "Failed copying Hmp.Uconfig to $ucfg_file: $!" );
            return;
        }

        # MSML media server configuration
        my $dst_file = '/usr/dialogic/cfg/media_server.xml';
        if ( $self->inst_version ) {

            # updating existing installation. Copy incoming file
            # with a version extension but keep the current one
            $dst_file .= '.' . $Xms_File_Version;
            ::log_msg( ::LL_VERBOSE, "Copying incoming media_server.xml to $dst_file. Keeping existing version" );
        }

        if ( ::copy( $self->path . '/media_server.xml', $dst_file ) ) {
            ::log_msg( ::LL_VERBOSE, "MSML media server setup OK" );
        }
        else {
            ::log_msg( ::LL_ERROR, "Failed to copy MSML media server configuration to $dst_file: $!" );
            return;
        }

        # Setup telnet port if required
        $self->_setup_telnet_port();

        # Remove unused services
        foreach my $sn ( 'ct_intel', 'tvl2_startup' ) {
            my $srv = Srv->new( name => $sn );
            if ( !$srv->remove() ) { return }
        }
        return 1;
    }

    sub Hmp::_setup_telnet_port {
        my $self           = shift;
        my $ctifile        = '/etc/init.d/ct_intel';
        my $ctifilebak     = $ctifile . '.bak';
        my $cti_filestatus = 0;
        if ( $self->cli_telnet_port() ) {
            my $port = $self->cli_telnet_port();
            if ( ::copy( $ctifile, $ctifilebak ) ) {
                if ( open( my $ctibakh, '<', $ctifilebak ) ) {
                    if ( open( my $ctifh, '>', $ctifile ) ) {
                        while ( my $line = <$ctibakh> ) {
                            if ( $line =~ s/^\s*CLI_LISTENER\s*=\s*\d+\b/CLI_LISTENER=$port/ ) {
                                $cti_filestatus = 1;
                            }
                            print $ctifh $line;
                        }
                        close($ctifh);
                    }
                    else {
                        ::log_msg( ::LL_ERROR, "Can't open file $ctifile for writing: $!" );
                    }
                    close($ctibakh);
                }
                else {
                    ::log_msg( ::LL_ERROR, "Can't open file $ctifilebak for reading: $!" );
                }
            }
            else {
                ::log_msg( ::LL_ERROR, "Can't back up file $ctifile : $!" );
            }

            if ($cti_filestatus) {
                ::log_msg( ::LL_VERBOSE, "HMP CLI Telnet port set to $port : OK" );
            }
            else {
                ::log_msg( ::LL_ERROR, "Could not setup HMP CLI Telnet port. Previous port setting remains unmodified." );
                $self->cli_telnet_port(0);
            }
        }
        return $cti_filestatus;
    }

    sub Hmp::_get_version {
        my $buildinfo_file = shift;
        my $hmp_version    = '';

        if ( -e $buildinfo_file ) {
            my $build_num = '';
            my @buildinfo = `cat $buildinfo_file`;
            foreach my $line (@buildinfo) {
                if ( $line =~ /^System Release Build Number\s*=\s*(\d\d\d+)/ ) { $build_num = $1 }
                if ( $line =~ /^System Release Minor Number\s*=\s*(\d\.\d)/ ) {
                    $hmp_version = $1;
                }
            }
            if ( $hmp_version and $build_num ) {
                $hmp_version .= ".$build_num";
                return $hmp_version;
            }
            else {
                ::log_msg( ::LL_ERROR, "Parsing HMP version from $buildinfo_file failed" );
            }
        }
        else {
            ::log_msg( ::LL_ERROR, "Can't get HMP version: $buildinfo_file does not exist" );
        }
        return;
    }

    sub Hmp::_open_archive {
        my $self    = shift;
        my $pkg_dir = $self->path;

        #get HMP tar file name
        my @hmp_tar_names = glob("$pkg_dir/lnxHMP_4.1_*.tgz");
        if ( scalar @hmp_tar_names > 1 ) {
            ::log_msg( ::LL_ERROR, "More than one HMP component was found in $pkg_dir : ", join( ' ', @hmp_tar_names ) );
            return;
        }

        if ( scalar @hmp_tar_names != 1 ) {
            ::log_msg( ::LL_ERROR, 'Missing HMP component $pkg_dir/lnxHMP_4.1_*.tgz' );
            return;
        }

        #extract the tar in a temp dir
        my $dir = File::Temp->newdir();
        if ( defined($dir) ) {

            if ( !::exec_log_stderr( 'tar', "--directory=$dir", '-xzf', $hmp_tar_names[0] ) ) {
                ::log_msg( ::LL_ERROR, 'HMP extraction failed.' );
                return;
            }
        }
        else {
            ::log_msg( ::LL_ERROR, "Can't create temp dir for HMP extraction" );
            return;
        }

        $self->_tar_dir($dir);

        return 1;
    }

    # Temporary.  To be removed once integrated into the build
    sub Hmp::_apply_webrtc_overlay {
        my $self    = shift;
        my $pkg_dir = $self->path;

        #get webrtc tar file name
        my @hmp_tar_names = glob("$pkg_dir/hmp_webrtc_build*.tgz");
        if ( scalar @hmp_tar_names > 1 ) {
            ::log_msg( ::LL_ERROR, "More than one webrtc overlay component package was found in $pkg_dir : ", join( ' ', @hmp_tar_names ) );
            return;
        }

        if ( scalar @hmp_tar_names != 1 ) {
            ::log_msg( ::LL_WARNING, 'Missing webrtc overlay component (hmp_webrtc_build*.tgz) in $pkg_dir' );
            return;
        }

        #extract the tar
        if ( -e '/usr/dialogic' ) {
            ::log_msg( ::LL_VERBOSE, "Applying webrtc overlay: $hmp_tar_names[0]" );
            if ( !::exec_log_stderr( 'tar',                      '--directory=/usr/dialogic',
                                     '--strip-components=1',     ' --xform=s/libipm_ipvsc.so/libipm_ovl.so/',
                                     '--show-transformed-names', '-xzvf',
                                     $hmp_tar_names[0]
                 )
              )
            {
                ::log_msg( ::LL_ERROR, 'webrtc overlay extraction failed.' );
                return;
            }
            else {
                ::log_msg( ::LL_VERBOSE, "Temporary webrtc overlay $hmp_tar_names[0] applied successfully" );
            }
        }
        else {
            ::log_msg( ::LL_ERROR, "/usr/dialogic does not exist. Skipping webrtc overlay" );
            return;
        }

        return 1;
    }
}

####################
# main
####################

sub main {

    verify_env() or exit(E_GEN_BAD_ENV);

    process_options() or exit(E_GEN_COMMAND_LINE);

    print $ConFd "\nDialogic Powermedia eXtended Media Server Installation Manager\n";

    if ( !log_init() ) {
        print "Error: Failed to initialize log file: $Xms_Log_File\n";
        exit(E_GEN_FAILED);
    }

    $SIG{'INT'}    = \&SIG_Cleanup_handler;
    $SIG{'ABRT'}   = \&SIG_Cleanup_handler;
    $SIG{'QUIT'}   = \&SIG_Cleanup_handler;
    $SIG{__WARN__} = \&SIG_Warn_handler;
    $SIG{__DIE__}  = \&SIG_Die_handler;

    $Errno = E_GEN_FAILED;

    init_data() or exit_cleanup($Errno);

    validate_request() or exit_cleanup($Errno);

    if ( is_install_mode(IM_TEST) ) {
        log_msg( LL_INFO, "Test report written to $Xms_Log_File." );
        exit_cleanup(0);
    }

    #get user input if in interactive mode
    get_user_input() or exit_cleanup($Errno);

    pre_process_tasks() or exit_cleanup($Errno);

    process_support_pkgs() or exit_cleanup($Errno);

    process_xms_core_pkgs() or exit_cleanup($Errno);

    process_hmp() or exit_cleanup($Errno);

    post_process_tasks() or exit_cleanup($Errno);

    exit_cleanup(E_OK);
}

#####################
# Script Entry Point
#####################
main();
