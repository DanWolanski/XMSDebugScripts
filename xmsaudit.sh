#!/bin/bash
# This script will gather all the system level information to ensure the XMS configuration enviorment
# License information and the latest version of this script can be found at
# https://github.com/Dialogic/UsefulScripts
# or run directly by Executing

. /etc/init.d/functions

starttime=`date +"%Y-%m-%d_%H-%M-%S"`
hostname=`hostname`
OUTFILE=xmsaudit-$hostname.tgz
LOG="xmsaudit-$hostname.log"
TMPPATH="/var/tmp/xmsaudit"

#logger -t SCRIPT  Executing $0, see $LOG in $TMPPATH for details
#mkdir $TMPPATH
#cd $TMPPATH


# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
step() {
    echo "#########################################################################" >> $LOG
    echo -n -e "$@"
    echo -e "STEP -  $@"&>> $LOG
    STEP_OK=0
    
}
next() {
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}
setpass() {
    echo -n "$@"
    STEP_OK=0
}
setfail() {
    echo -n "$@"
    STEP_OK=1
}

log(){
	echo "$@" >> $LOG
}

logx(){
	echo "----------------------------------------------------------------------------" &>> $LOG
	echo "$@" >> $LOG
	echo "---------------------" &>> $LOG
	"$@" &>> $LOG
}

echo "Starting Audit - $starttime" > $LOG
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
step "Checking frequently misconfigured items"
echo "----------------------------------------------------------------------------" &>> $LOG
log "XMS release version and state"
echo "----" &>> $LOG
curl -s http://127.0.0.1:10080/system | grep state >> $LOG
echo "" &>> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "CPUs on system"
echo "----" &>> $LOG
lscpu | grep -P "^CPU\(s\):|name:" >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "Mem on system"
echo "----" &>> $LOG
free -ml >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "disk space"
echo "----" &>> $LOG
df -h >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "SELinux should be disabled"
echo "----" &>> $LOG
sestatus >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "etc/hosts should have the fqdn and hostname set"
echo "----" &>> $LOG
cat /etc/hosts >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "Check that you can ping the hostname, confirm this to your dir"
echo "----" &>> $LOG
ping `hostname` -c 1 >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "Check that you can ping the an internet location"
echo "----" &>> $LOG
ping www.dialogic.com -c 1 >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "Check if cache is enabled"
echo "----" &>> $LOG
curl -s http://127.0.0.1:10080/httpclient >> $LOG
echo "" &>> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "check rp_filter disabled"
echo "----" &>> $LOG
sysctl -A | grep .rp_filter >> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "check for the checksum disabled"
echo "----" &>> $LOG
for nic in `ls /sys/class/net` ; 
do 
 ethtool --show-offload $nic | grep checksum   >> $LOG ;
done 
echo "----------------------------------------------------------------------------" &>> $LOG
log "check the sip settings"
echo "----" &>> $LOG
curl -s http://127.0.0.1:10080/sip >> $LOG
echo "" &>> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "check the rtp settings" 
echo "----" &>> $LOG
curl -s http://127.0.0.1:10080/rtp >> $LOG
echo "" &>> $LOG
echo "----------------------------------------------------------------------------" &>> $LOG
log "check the lic"
echo "----" &>> $LOG
curl -s http://127.0.0.1:10080/license >> $LOG
echo "" &>> $LOG
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
setpass
next

step "Gather basic System Information"
logx hostname
logx hostnamectl
logx cat /etc/system-release
logx cat /etc/redhat-release
logx sestatus
logx lscpu
logx free -ml
logx df -h
logx ip a
logx curl http://127.0.0.1:10080/system
logx cat /proc/meminfo

setpass;
next


step "Gathering Network configuration"
logx ifconfig
logx ifconfig -a
logx ip a
logx netstat -anope
logx route
setpass;
next

step "Gather Firewall Information"
logx iptables --list
logx firewall-cmd --list-all-zones
setpass;
next

step "Gathering process and package information"
logx cat /etc/system-release
logx cat /etc/redhat-release
logx ps -Afe
logx rpm -qa 
logx yum history info
logx systemctl list-unit-files
logx chkconfig --list
logx crontab -l 
log cron tasks
cat /etc/passwd | sed 's/^\([^:]*\):.*$/crontab -u \1 -l 2>\&1/' | grep -v "no crontab for" | sh >> $LOG
setpass;
next




step "Collecting system usage and performance data"
logx uptime
logx top -b -n 1 
logx sar -A 
logx cat /proc/cpuinfo
logx lscpu
logx free -ml
logx cat /var/lib/xms/meters/currentValue.txt
setpass;
next

step "Collecting other system and configuration data"
logx env
for nic in `ls /sys/class/net` ; 
do 
logx ethtool --show-offload $nic; 
done 
logx lspci
logx sysctl -A 
logx dmidecode 
logx dmesg
logx ulimit -a
logx uname -a
setpass;
next

step "Collecting XMS WebUI information"
OAMHOST="127.0.0.1"
OAMPORT="10080"
dumpsubs(){
local CURPATH=$1
local RESPONSE="$(curl -s http://$OAMHOST:$OAMPORT$CURPATH)"
log "------------------------------------------------------------------------------" 
log "$CURPATH"
log "$RESPONSE" 
local ITEMS="$(echo -e "$RESPONSE" |grep uri |  grep resource | awk -F'"' '{print $2}')"
#echo $ITEMS
for item in $ITEMS
do
	#omit getting the media and backup for performance sake
	 if [[ ${CURPATH} != *"/media/prompts"* ]] && [[ ${CURPATH} != *"/system/backup"* ]]; then
   		dumpsubs "$CURPATH/$item"
	fi
done
}
log "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
log "XMS FULL WebUI Dump" 
log "host:      `hostname`" 
log "OAM:       http://$OAMHOST:$OAMPORT" 
log "starttime: $starttime" 
log "Outfile:   $OUTFILE" 
log "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
dumpsubs ""
setpass;
next


step "Collecting XMS Cache file information"


log "Cache Info"
logx  `ls -l /var/cache/xms/http/xmserver/ |wc -l` files found in cache 
log "Files- "
logx ls -la /var/cache/xms/http/xmserver/ 
setpass;
next


step "Saving directory and file information"
declare -a dirs=(
"ls -atlR /usr/dialogic" 
"ls -altR /etc/xms" 
"ls -altR /var/lib/xms"
"ls -altR /usr/bin"
)

for i in "${dirs[@]}"
do
   
   logx $i 
   
done
setpass;
next


step "Collecting for XMS core dump information"
log "Listing:"
logx ls -altr /var/tmp/abrt
log "last-ccpp:"
logx cat /var/tmp/abrt/last-ccpp 


for filename in /var/tmp/abrt/*; do
if [ -d $filename ]
then
        echo "======================== START ================================" &>> $LOG
        echo "$filename" &>> $LOG
        echo "===============================================================" &>> $LOG
        echo "                     EXECUTABLE                                " &>> $LOG
        echo "---------------------------------------------------------------" &>> $LOG
        cat $filename/executable &>> $LOG
        echo "" &>> $LOG
        echo "---------------------------------------------------------------" &>> $LOG
        echo "                      REASON                                   " &>> $LOG
        echo "---------------------------------------------------------------" &>> $LOG
        cat $filename/reason &>> $LOG
        echo "" &>> $LOG
        echo "---------------------------------------------------------------" &>> $LOG
        echo "                     BACKTRACE                                 " &>> $LOG
        echo "---------------------------------------------------------------" &>> $LOG
        cat $filename/core_backtrace &>> $LOG
        echo "" &>> $LOG
        echo "===============================================================" &>> $LOG
        echo "$filename" &>> $LOG
        echo "=====================i===  END  ===============================" &>> $LOG
fi
done
setpass;
next


step "Compressing system and XMS debug logs"
tar cvzf $OUTFILE --exclude='*.tgz' --exclude='xmsbackup*.tar.gz' /var/log/xms /var/log/dialogic /var/log/messages* /etc/profile.d/ct_intel.sh /etc/xms /usr/dialogic/cfg /etc/hosts /var/lib/xms/meters/currentValue.txt /etc/fstab /etc/cluster/cluster.conf /etc/sysctl.conf /etc/sysconfig &>/dev/null
setpass;
next

#echo -e "\n\n File saved to $O\n\n"
