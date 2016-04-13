#!/bin/bash
. /etc/init.d/functions

PATCHNAME=""
# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
step() {
    echo -n "$@"

    
    echo "STEP -  $@">> patch.log
    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@" >> patch.log 
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \'$*\' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
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
setfail() {
    echo -n "$@"

    STEP_OK=1
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}


#check that an argument was passed
if [ -z "$@"  ]
then
    echo Missing argument!  
    echo Ex:
    echo "./patch.sh testpatch.zip/.tgz)"
    echo             or
    echo "./patch.sh restore restore_testpatch.zip/.tgz)"
	exit 1
  
fi 

echo "Applying patch $@" > patch.log
echo "Stopping XMS Services:"
service nodecontroller stop

step "Backup /usr/dialogic tree for restore if needed"
try tar cvzf restore-$@.tgz /usr/dialogic /usr/bin/xmserver 2> /dev/null
next

echo "Files before patch:" >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libipp* >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libxcf* >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libxpf* >> patch.log
ls -l --color=auto /usr/dialogic/data/ssp.mlm* >> patch.log
ls -l --color=auto /usr/dialogic/bin/ssp_x86Linux_boot* >> patch.log
ls -l --color=auto /usr/bin/xmserver >> patch.log
echo "----------------------------------------------------------" >>patch.log 
md5sum /usr/dialogic/lib64/libipp* >> patch.log
md5sum /usr/dialogic/lib64/libxcf* >> patch.log
md5sum /usr/dialogic/lib64/libxpf* >> patch.log
md5sum /usr/dialogic/data/ssp.mlm* >> patch.log
md5sum /usr/dialogic/bin/ssp_x86Linux_boot* >> patch.log
md5sum  /usr/bin/xmserver >> patch.log
echo "----------------------------------------------------------" >>patch.log 
echo "ct_intel script contents" >> patch.log
cat /etc/init.d/ct_intel >> patch.log

echo "----------------------------------------------------------" >>patch.log 
step "Extacting tar file"
try tar xvzf $@
next

echo "Files in tgz" >> patch.log
ls -l --color=auto  * >> patch.log
echo "----------------------------------------------------------" >>patch.log
 
step "Copy over Library files to /usr/dialogic/lib"
try \cp -f *.so.1 /usr/dialogic/lib64
next

step "Copy over ssp.mlm to /usr/dialogic/data"
try \cp -f ssp.mlm* /usr/dialogic/data
next

step "Copy over ssp_x86Linux_boot to /usr/dialogic/bin"
try \cp -f ssp_x86Linux_boot /usr/dialogic/bin
next

step "Copy over xmserver to /usr/bin"
try \cp -f xmserver /usr/bin
next

step "Copy over ct_intel to /etc/init.d"
try \cp -f ct_intel /etc/init.d
next
step "Resetting permisions on ssp_x86Linux_boot"
try chmod +x /usr/dialogic/bin/ssp_x86Linux_boot ; chmod +x /usr/bin/xmserver ; chmod +x /etc/init.d/ct_intel
next

echo "Files after patch:" >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libipp* >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libipp* >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libxcf* >> patch.log
ls -l --color=auto /usr/dialogic/lib64/libxpf* >> patch.log
ls -l --color=auto /usr/dialogic/data/ssp.mlm* >> patch.log
ls -l --color=auto /usr/dialogic/bin/ssp_x86Linux_boot* >> patch.log
ls -l --color=auto /usr/bin/xmserver >> patch.log
echo "----------------------------------------------------------" >>patch.log 
md5sum /usr/dialogic/lib64/libipp* >> patch.log
md5sum /usr/dialogic/lib64/libxcf* >> patch.log
md5sum /usr/dialogic/lib64/libxpf* >> patch.log
md5sum /usr/dialogic/data/ssp.mlm* >> patch.log
md5sum /usr/dialogic/bin/ssp_x86Linux_boot* >> patch.log
md5sum /usr/bin/xmserver >> patch.log
echo "----------------------------------------------------------" >>patch.log 
echo "ct_intel script contents" >> patch.log
cat /etc/init.d/ct_intel >> patch.log
echo "----------------------------------------------------------" >>patch.log 
step "Cleaning out /var/log/ files"
try \rm -f /var/log/xms/* ; \rm -f /var/log/dialogic/*
next

echo "Restarting Dialogic Services:"
service nodecontroller start

echo " "
echo " "
echo ===============================
echo = Patch Completed Successful! =
echo ===============================
