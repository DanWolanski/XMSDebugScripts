#!/bin/bash
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

starttime=`date +"%Y-%m-%d_%H-%M-%S"`
#LOG="xmserrorcheck-$starttime.log"
LOG="xmserrorcheck.log"
#Change this to change the messages file location
FILEDIR="/var/log/messages*"
#FILEDIR="./messages*"

#Modify these strings to change what the start message and the ERROR message you are looking for
STARTMESSAGE="BOARDMANAGER: From Component: CBMEvMgr : EVENT : SysReady .READY."
ERRORMESSAGE="appmanager: .*? AppManager::onHangup.*?response from app:"
#Comment this out to not clear log each time
echo "" > $LOG
echo "Script Started on $starttime" | tee -a $LOG
echo "Checking $FILEDIR" | tee -a $LOG
echo 
LASTSTART=$(grep -P "$STARTMESSAGE" $FILEDIR | sort | tail -n 1)
startTimeString=$(echo $LASTSTART | tr -s " " | cut -d " " -f1-3 | cut -d ":" -f2-5)
echo "Last System Restart:" | tee -a $LOG
echo "  time = $startTimeString" | tee -a $LOG
echo "  message = [[ $LASTSTART ]]" | tee -a $LOG

echo
LASTERROR=$(grep -P "$ERRORMESSAGE" $FILEDIR | sort | tail -n 1)
errorSeenTimeString=$(echo $LASTERROR | tr -s " " | cut -d " " -f1-3 | cut -d ":" -f2-5)
echo "Last ERROR seen: " | tee -a $LOG
echo "  time = $errorSeenTimeString" | tee -a $LOG       
echo "  message = [[ $LASTERROR ]]" | tee -a $LOG

lastStartTime=$(date -d "$startTimeString" +%s)
lastErrorTime=$(date -d "$errorSeenTimeString" +%s)
echo
if [ $lastErrorTime -gt $lastStartTime ]
then
  echo -e "\033[33;7mERROR was seen since last XMS service restart, please restart XMS service \033[0m"
#Custom code for what to do on detection can be added here
  exit
else
  echo -e "\033[32;7mNO ERROR was seen since last XMS service restart!! \033[0m"
fi
