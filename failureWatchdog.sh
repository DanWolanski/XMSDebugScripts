#!/bin/bash


PORTCOUNT=$(curl -s http://127.0.0.1:10080/license | grep basic_audio | awk -F'"' '{print $6}')
PORTTHRESH=$(echo "$PORTCOUNT*.9" | bc | awk -F'.' '{print $1}')
echo -e "$PORTCOUNT Basic Audio Ports are found from WebUI"
echo -e "$PORTTHRESH is the 90% usage threshold"

setStartCounts(){
    IPTERRORSTARTCOUNT=$(grep 'DeviceManager::allocIptDevice() device: ipt' /var/log/messages | grep unavailable | wc -l)
    if [ -z "$IPTERRORSTARTCOUNT" ]
     then
     IPTERRORSTARTCOUNT=0
    fi
    MEDIAERRORSTARTCOUNT=$(grep  'failed to create stream' /var/log/messages | wc -l )
    if [ -z "$MEDIAERRORSTARTCOUNT" ]
     then
     MEDIAERRORSTARTCOUNT=0
    fi
    RESTARTSTARTCOUNT=$(grep  'From Component: CLI : @ EVENT-- SYSTEM' /var/log/messages|grep ready | wc -l )
    if [ -z "$RESTARTSTARTCOUNT" ]
     then
     RESTARTSTARTCOUNT=0
    fi

    echo -e "IPTErrorStartCount=$IPTERRORSTARTCOUNT, MediaErrorCountStart=$MEDIAERRORSTARTCOUNT, XMSRestartCount=$RESTARTSTARTCOUNT"

}

onFailure(){
       
	FAILURETIME=`date +"%y-%m-%d:%H-%m-%s"`
        echo -e $1

        logger "failureWatchdog.sh detected a fault - $1"
	echo "Executing xmsinfo.sh watchdog-$FAILURETIME"
        ./xmsinfo.sh

	
#to exit comment this to prevent from exit on failure
        KEEPLOOPING=false
	continue 
#note will not get here if keeplooping line is uncommented

#otherwise pause watching to prevent generation of log files
	echo -e "\nSleeping for 30mins before resuming"
        sleep 1800
	echo -e"\nResuming watchdog"

	setStartCounts

}


setStartCounts

KEEPLOOPING=true
while $KEEPLOOPING;
do
sleep 60

echo -n .
#check the messages file
IPTERRORS=$(grep 'DeviceManager::allocIptDevice() device: ipt' /var/log/messages | grep unavailable | wc -l)
#check to see if count went down, if it did reset count because file rolled over
if [ "$IPTERRORS" -le "$IPTERRORSTARTCOUNT" ]
then
IPTERRORSTARTCOUNT=$IPTERRORS
else
onFailure "Detected increase in IPT Errors (OldCount=$IPTERRORSTARTCOUNT, NewCount=$IPTERRORS)"

fi 

MEDIAERRORS=$(grep  'failed to create stream' /var/log/messages | wc -l )

#check to see if count went down, if it did reset count because file rolled over
if [ "$MEDIAERRORS" -le "$MEDIAERRORSTARTCOUNT" ]
then
MEDIAERRORSTARTCOUNT=$MEDIAERRORS
else
onFailure "Detected increase in Media Errors (OldCount=$MEDIAERRORSTARTCOUNT, NewCount=$MEDIAERRORS)"
fi

STARTCOUNT=$(grep  'From Component: CLI : @ EVENT-- SYSTEM' /var/log/messages|grep ready | wc -l )


#check to see if count went down, if it did reset count because file rolled over
if [ "$STARTCOUNT" -le "$RESTARTSTARTCOUNT" ]
then
RESTARTSTARTCOUNT=$STARTCOUNT
else
onFailure "Detected increase in Restart (OldCount=$RESTARTSTARTCOUNT, NewCount=$STARTCOUNT)"
fi

#check signaling
RTPCOUNT=$(cat /var/lib/xms/meters/currentValue.txt | grep xmsResources.xmsRtpSessions | awk -F' ' '{print $3}')
#echo -e "RTPCOUNT=$RTPCOUNT"

if [ -z "$RTPCOUNT" ]
then
  #echo "Failed to read meters information"
  continue
else
  if [ "$RTPCOUNT" -ge "$PORTTHRESH" ]
  then
  onFailure "RTP Count Exceeded, count=$RTPCOUNT thresh=$PORTTHRESH"
  fi

fi

#check Signaling
SIPCOUNT=$(cat /var/lib/xms/meters/currentValue.txt | grep xmsResources.xmsSignalingSessions | awk -F' ' '{print $3}')
#echo -e "SIPCOUNT=$SIPCOUNT"

if [ -z "$SIPCOUNT" ]
then
  #echo "Failed to read meters information"
  continue
else
  if [ "$SIPCOUNT" -ge "$PORTTHRESH" ]
  then
  onFailure "SIP Count Exceeded, count=$SIPCOUNT thresh=$PORTTHRESH"
  fi

fi

#check media transactions
MEDIACOUNT=$(cat /var/lib/xms/meters/currentValue.txt | grep xmsResources.xmsMediaTransactions | awk -F' ' '{print $3}')
#echo -e "MEDIACOUNT=$MEDIACOUNT"

if [ -z "$MEDIACOUNT" ]
then
  #echo "Failed to read meters information"
  continue
e