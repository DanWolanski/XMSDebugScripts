#!/bin/bash
. /etc/init.d/functions


starttime=`date +"%Y-%m-%d_%H-%M-%S"`

LOG="promptConvert.log"
STARTPATH="."
if [ $# -eq 1 ]; then
	STARTPATH=$1
fi
COUNT=0
echo "Start time is $starttime" > $LOG
echo "  STARTPATH=$STARTPATH" >> $LOG
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
step() {
    echo -n -e "$@"
    echo -e "\n\nSTEP -  $@"&>> $LOG
    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}
next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}
setpass() {
    echo -n "$@"
    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}


#START
#check if sox is installed
step "Checking for sox tool"
command -v sox >/dev/null 2>&1 || { echo >&2 "Script requires sox (SoX) but it's not installed.  Please install via package manager before proceeding"; exit 1; }
setpass
next

step "Converting:\n"
# can be installed via yum install sox
# for AMR confersion, you will need the aditional libs
#  yum install opencore-amr

#FILELIST=$(find $STARTPATH \( -name '*.WAV' -or -name '*.wav' -type f \) -print0 )
#for f in $FILELIST; do
for f in $STARTPATH/* $STARTPATH/**/* ; do
  if [ -f "$f" ]
  then
  #only supporting WAV or wav files in this convert
  if [[ $f =~ .*\.(WAV|wav) ]]
    then
    let COUNT=COUNT+1
    echo "==============================   $f   ========================================" >> $LOG
    soxi "$f" >> $LOG
    filebase=`echo $f | rev | cut -f 2- -d '.' | rev`
    SOXARGS="-b 8 -c 1 -r 8k -e u-law "
    echo "   Filebase=$filebase" >> $LOG
    echo "   Creating ulaw Version via sox  $f $SOXARGS "$filebase".ul" >> $LOG
    sox "$f" $SOXARGS  "$filebase".ul &>> $LOG
    echo "   Convert complete - new file information" >> $LOG
    soxi "$filebase".ul &>> $LOG

    echo "  renaming "$filebase".ul file to "${filebase,,}".ulaw" >> $LOG
    mv "$filebase".ul "${filebase,,}".ulaw &>> $LOG

    echo "#$COUNT: $f => "${filebase,,}".ulaw" | tee -a $LOG
    #echo "   Creating AMR Version" >> $LOG
    #sox $f -b 8 -c 1 -r 16k -e u-law {$filebase}.ul &>> $LOG

    fi
  fi
done
setpass
echo -e -n "\n\nProcess complete, $COUNT files converted  "
next
echo -e "\nSee $LOG for details."
