#!/bin/bash 

#rin with this commandline
# nohup ./failureWatchdog > failureWatchdog.log& 
SCRIPTDIR="/root/scripts"

RESTARTONPORTTHRESH=true
LOOPTIME=60
FAILURESCRIPT="gracefulRestart.sh"

PORTCOUNT=$(curl -s http://127.0.0.1:10080/license | grep basic_audio | awk -F'"' '{print $6}')
PORTTHRESH=$(echo "$PORTCOUNT*.9" | bc | awk -F'.' '{print $1}')
echo -e "$PORTCOUNT Basic Audio Ports are found from WebUI"
echo -e "$PORTTHRESH is the 90% usage threshold"
echo -e "Restart on Port Threshold = $RESTARTONPORTTHRESH"

CREATESTREAMFAIL="^(.*)appmanager:.*AppManager::onAckCreateStream.*failed to create stream, rejecting call.*";
MEDIAFAIL="^(.*)xmserver:.*ERROR  MediaServer::onCreateStream.*Media not available.*";
ADECERROR="^(.*)ssp_x86Linux_boot: ADEC.* could not write packet to .*";
STARTSTR="^(.*)root: Starting: nodecontroller.*";
STOPSTR="^(.*)root: Stopping: nodecontroller.*";

setStartCounts(){
    #Set the default count for Media Errors
    ERRORSTARTCOUNT=$(grep  -P "$MEDIAFAIL|$CREATESTREAMFAIL|$ADECERROR" /var/log/messages | wc -l )
    if [ -z "$ERRORSTARTCOUNT" ]
     then
     ERRORSTARTCOUNT=0
    fi
    
    echo -e "StartingErrorCount = $ERRORSTARTCOUNT"

}

onFailure(){
       
	FAILURETIME=`date +"%y-%m-%d:%H-%m-%s"`
        echo -e $1

        logger "failureWatchdog.sh detected a fault - $1"
	echo "Executing $FAILURESCRIPT @$FAILURETIME"
        $SCRIPTDIR/$FAILURESCRIPT

	
#to exit comment this to prevent from exit on failure
    #KEEPLOOPING=false
	#continue 
#note will not get here if keeplooping line is uncommented

	setStartCounts

}

logger "Starting failureWatchdog.sh"
#init the counters
setStartCounts

KEEPLOOPING=true
while $KEEPLOOPING;
do

timeout $LOOPTIME $SCRIPTDIR/messagefilewatcher.sh


#cat /dev/null > tshark.out 
#tshark -i any -R sip | grep -i "SIP Status: 503 Service Unavailable" > tshark.out &
#PID=$!
# Wait for 30 seconds
#timeout $LOOPTIME $SCRIPTDIR/messagefilewatcher.sh
# Kill it
#kill $PID
#TSHARKERRORCOUNT=0
#TSHARKERRORCOUNT=$(grep -i "SIP Status: 503 Service Unavailable" tshark.out | wc -l )
#check to see if count went down, if it did reset count because file rolled over
#if [ "$TSHARKERRORCOUNT" -ge "1" ]
#then
#onFailure "Detected 503 in SIP capture"
#fi 



ERRORCOUNT=$(grep  -P "$MEDIAFAIL|$CREATESTREAMFAIL|$ADECERROR" /var/log/messages | wc -l )
#check to see if count went down, if it did reset count because file rolled over
if [ "$ERRORCOUNT" -le "$ERRORSTARTCOUNT" ]
then
ERRORSTARTCOUNT=$ERRORCOUNT
else
onFailure "Detected increase messages file Errors (OldCount=$ERRORSTARTCOUNT, NewCount=$ERRORCOUNT)"

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
else
  if [ "$MEDIACOUNT" -ge "$PORTTHRESH" ]
  then
  onFailure "Media Count Exceeded, count=$MEDIACOUNT thresh=$PORTTHRESH"
  fi
 
fi

done
echo -e "Exiting failureWatchdog, failure timestamp is $FAILURETIME" 
logger "Exiting failureWatchdog.sh"
