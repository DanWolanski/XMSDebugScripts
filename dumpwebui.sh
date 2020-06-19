#!/bin/bash
starttime=`date +"%y-%m-%d_%H-%m-%s"` 
OUTFILE=xmswebuidump-$starttime

if [ $# -eq 1 ]; then
	OUTFILE=$1
fi

OAMHOST="127.0.0.1"
OAMPORT="10080"

dumpsubs(){
local CURPATH=$1
local RESPONSE="$(curl -s http://$OAMHOST:$OAMPORT$CURPATH)"
echo -e "------------------------------------------------------------------------------"
echo -e "$CURPATH"
echo -e "------------------------------------------------------------------------------"
echo -e "$RESPONSE" 
local ITEMS="$(echo -e "$RESPONSE" |grep uri |  grep resource | awk -F'"' '{print $2}')"
#echo $ITEMS

for item in $ITEMS
do
   dumpsubs "$CURPATH/$item" 
done

}
echo "" > $OUTFILE
echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $OUTFILE
echo -e "XMS WebUI Dump" | tee -a $OUTFILE
echo -e "host:      `hostname`" | tee -a $OUTFILE
echo -e "OAM:       http://$OAMHOST:$OAMPORT" | tee -a $OUTFILE
echo -e "starttime: $starttime" | tee -a $OUTFILE
echo -e "Outfile:   $OUTFILE" | tee -a $OUTFILE
echo -e "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" | tee -a $OUTFILE
dumpsubs "" | tee -a $OUTFILE
