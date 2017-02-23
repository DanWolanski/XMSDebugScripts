#!/bin/bash
# This script will attempt to remove user information such as DTMF events
# from the various XMS logs
# License information and the latest version of this script can be found at
# https://github.com/Dialogic/UsefulScripts
if [ -e "/etc/init.d/functions" ];
then
. /etc/init.d/functions
else
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
OFFSET='\033[60G'
echo_success(){
  echo -en \\033
  echo -en "${OFFSET}${GREEN}[OK]${NC}";
}
echo_failure(){
echo -en "${OFFSET}${RED}[FAIL]${NC}";
}
fi

LOGDIR="."
starttime=`date +"%Y-%m-%d_%H-%M-%S"`
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
step() {
    echo -n -e "$@"
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
#####################
# appmanager lines  #
#####################
step "Scrubbing Appmanager Logs"
#2017-02-22 13:39:44.391151 DEBUG  sid:3a5cc3b0b2eb404fadd1e17ed1190f56 AppManager::onDtmf() source: stream, id: 0c111e65-9d14-4f2e-9b4d-766b9d185aa9, digits: "X"
#sed -i  's/\"digits\" : \".*\"/\"digits\" : \"X\"/g' $LOGDIR/appmanager-*

#{
#	"type" : "DTMF",
#	"gusid" : "3a5cc3b0b2eb404fadd1e17ed1190f56",
#	"call_id" : "6fb06715-e534-4552-9f21-8caa5df65bd4",
#	"digits" : "X",
#	"duration" : "100",
#	"interval" : "100",
#	"level" : "-10"
#}
sed -i  '
s/digits: \".*\"/digits: \"XX\"/g;
s/\"digits\" : \".*\"/\"digits\" : \"XX\"/g
' $LOGDIR/appmanager-*

next
#####################
# Broker Log lines  #
#####################
step "Scrubbing Broker Logs"
#DTMF
#{
#	"Type" : "DTMF",
#	"Source-Id" : "0c111e65-9d14-4f2e-9b4d-766b9d185aa9",
#	"Source-Type" : "stream",
#	"Media-Id" : "",
#	"Digits" : "1",
#	"Duration" : "600",
#	"Interval" : "100",
#	"Level" : "-10"
#}

sed -i  '
s/\"Digits\" : \".*\"/\"Digits\" : \"XX\"/g
' $LOGDIR/broker-*

next

#####################
# XMServer Log      #
#####################
step "Scrubbing XMServer Logs"
#2017-02-22 13:39:44.390539 DEBUG  sid:3a5cc3b0b2eb404fadd1e17ed1190f56 IpmDevice::onTelephonyEvent() TelephonyEventID: 0x1 600ms
#2017-02-22 13:39:44.390582 DEBUG  sid:3a5cc3b0b2eb404fadd1e17ed1190f56 MediaServer::sendDtmf() id: 0c111e65-9d14-4f2e-9b4d-766b9d185aa9, digits: "1" 600
sed -i  '
s/digits: \".*\"/digits: \"XX\"/g;
s/TelephonyEventID: .../TelephonyEventID: 0xXX /g
' $LOGDIR/xmserver-*

next

#####################
# Vxml Log 	    #
#####################
step "Scrubbing VXML Logs"
#2017-02-22 13:39:44.391694 DEBUG   sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [I/O] [1:7f7a8c3e4700] CMIOManager::Callback - Status: LOG_MESSAGE_FROM_MIO - CVoiceXMLSIPDialogManager::ProcessXmsEvents - type : DTMF
#2017-02-22 13:39:44.391778 DEBUG   sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [I/O] [1:7f7a8c3e4700] CMIOManager::Callback - Status: LOG_MESSAGE_FROM_MIO - CVoiceXMLSIPDialogManager::ProcessXmsEvents - digits : 1
#sed -i  's/digits : .*/digits : X/g' $LOGDIR/vxml*.log

#2017-02-22 13:39:44.392107 DEBUG   sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [I/O] [1:7f7a8c7e8700] CMIOManager::Callback - Status: LOG_MESSAGE_FROM_MIO - CMRCPController::ProcessDTMF - Got DTMF-1, dtmfterm=0, grammar active=1
#sed -i 's/ Got DTMF-.*,/ Got DTMF-XX,/g' $LOGDIR/vxml*

#2017-02-22 13:39:44.392173 DEBUG   sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [I/O] [1:7f7a8c7e8700] CMIOManager::Callback - Status: LOG_MESSAGE_FROM_MIO - CMRCPController::LogDRLMessage - CDTMFRecognizer::ProcessDTMF(1) in state 1
#sed -i 's/ProcessDTMF(.*)/ProcessDTMF(X)/g' $LOGDIR/vxml*.log

#2017-02-22 13:40:24.392342 DEBUG   sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [I/O] [1:7f7a8dcef700] CMIOManager::Callback - Status: LOG_MESSAGE_FROM_MIO - CMRCPController::LogDRLMessage - Recognizing against buffer 3
#sed -i 's/Recognizing against buffer.*/Recognizing against buffer X/g' $LOGDIR/vxml*.log

#2017-02-22 13:40:24.393145 INFO    sid:3a5cc3b0b2eb404fadd1e17ed1190f56 [VoiceXmlInterpreter] [1:7f7a8c2e3700] ::APP_MESSAGE - 22/02/17 13:40:24 INFO   [Recognition] Utterance: '3'; Confidence: 1.00; Input Mode: 'dtmf'; Interpretation: '3'; Type=5
#lastresult$.recording = undefined;
#lastresult$.recordingsize = undefined;
#lastresult$.recordingduration = undefined;
#lastresult$.recordinghttp = '';
#lastresult$.markname = undefined;
#lastresult$.marktime = undefined;
#lastresult$.utterance = '3';
#lastresult$.confidence = 1.0000;
#lastresult$.inputmode = 'dtmf';
#lastresult$.interpretation = '3';
#lastresult$.bargeintime = 35173;
#lastresult$[0] = new Object();
#lastresult$[0].utterance = '3';
#lastresult$[0].confidence = 1.0000;
#lastresult$[0].inputmode = 'dtmf';
#lastresult$[0].interpretation = '3';
#lastresult$[0].bargeintime = 35173; 
sed -i '
s/digits : .*/digits : XX/g;
s/ Got DTMF-.*,/ Got DTMF-XX,/g;
s/ProcessDTMF(.*)/ProcessDTMF(XX)/g;
s/Recognizing against buffer.*/Recognizing against buffer XX/g;
s/Utterance: .[0-9|a-e]*.;/Utterance: XX/g;
s/utterance = .[0-9|a-e]*.;/utterance = XX/g;
s/Interpretation: .[0-9|a-e]*.;/Interpretation: XX/g;
s/interpretation = .[0-9|a-e]*.;/interpretation = XX/g
' $LOGDIR/vxml*.log

next
echo 
echo "Process Complete"
echo 
