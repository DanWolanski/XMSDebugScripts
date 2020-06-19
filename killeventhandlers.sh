#!/bin/bash
starttime=`date +"%Y-%m-%d_%H-%M-%S"`
scriptname=$0
STARTPWD=$(pwd)
#LOG=${STARTPWD}/occasinstall.log
LOG='/dev/null'
EXITONFAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
OFFSET='\033[60G'

echo_success(){
  echo -en \\033
  echo -en "${OFFSET}[  ${GREEN}OK${NC}  ]\n";
  echo -e "\n**** Step SUCCESS ****\n\n" >> $LOG
}
echo_failure(){
echo -en "${OFFSET}[${RED}FAILED${NC}]\n";
echo -e "\n**** Step FAILURE ****\n\n" >> $LOG
}
step() {
	ERRCOUNT=0
	echo "===========================================================================================" >> $LOG
	echo "====   Step - $@" >> $LOG
	echo "===========================================================================================" >> $LOG
    echo -n -e "$@"
	logger -t "$scriptname" "$@"
	
}
try (){
    $@ &>> $LOG 
    if [[ $? -ne 0 ]] ; then 
		echo "ERROR!!" &>> $LOG
		let ERRCOUNT+=1
     fi
}

next (){
    
    if [[ $ERRCOUNT -ne 0 ]] ; then 
		echo_failure  
     else 
		echo_success 
     fi
	ERRCOUNT=0
}
log(){
    echo -e "$@" |& tee -a $LOG
}
setpass(){
	echo "Manually setting PASS" &>> $LOG
	let ERRCOUNT+=0
}
setfail(){
	echo "Manually setting FAIL" &>> $LOG
	let ERRCOUNT+=1
}
echo
###########################################################################
#######                Start of script                             ########
####i#######################################################################
SERVERIP="127.0.0.1"
SERVERPORT="81"
APPID="app"

while getopts 'i:a:p:' flag; do
 case "${flag}" in
	i) SERVERIP="$OPTARG" 
	#log "arg - Media Server IP specified as $OPTARG" 
    ;;
	a) APPID="$OPTARG" 
	#log "arg - REST appid $APPID" 
    ;;
	p) SERVERPORT="$OPTARG" 
	#log "arg - REST port $SERVERPORT" 
    ;;
    *) error "Unexpected option ${flag}" 
    log "Usage:"
    log "$scriptname [-i serverip (default=127.0.0.1)] [-a appid (default=app)] [-p port (default=81)]";;
  esac
done

CURLURI="http://${SERVERIP}:${SERVERPORT}/default/eventhandlers?appid=${APPID}"
log "Target URI ${CURLURI}"

step "Fetching handler list from Server"

HANDLERS=$(curl -s ${CURLURI} | grep -oP '(?<=href=")\/default\/eventhandlers\/.*?(?=")')
next

HANDLERSCOUNT=$(echo $HANDLERS | grep eventhandlers | wc -l )
log "   $HANDLERSCOUNT EventHandlers Detected"

if [ $HANDLERSCOUNT -ne "0" ] 
then
log "Deleting Handlers:"
for handler in $HANDLERS ; do
URI=$(echo   $handler | grep -oP '(?<=\/default\/eventhandlers\/).*')
step "   $URI"
curl -s -X DELETE http://${SERVERIP}:${SERVERPORT}${handler}?appid=${APPID}
next
    
done

step "Rescanning for EventHandlers"
HANDLERS=$(curl -s ${CURLURI} | grep -oP '(?<=href=")\/default\/eventhandlers\/.*?(?=")')
next

HANDLERSCOUNT=$(echo $HANDLERS |grep eventhandlers |  wc -l)
log "   $HANDLERSCOUNT EventHandlers Detected"
if [ $HANDLERSCOUNT -ne "0" ] 
then
log "${GREEN}All Handlers Deleted !! ${NC}"
else
log "${RED}${HANDLERSCOUNT} Handlers still detected !! ${NC}"
fi

else
echo
log "${GREEN}No active EventHandlers found${NC}"
fi






