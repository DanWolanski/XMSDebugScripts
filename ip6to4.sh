#!/bin/bash
# this file will convert and RTPDump file to an IPv4 formated file.  It requiresthe suse of the RTPtools
#http://www.cs.columbia.edu/irt/software/rtptools/download/

. /etc/init.d/functions

INFILE=rtpstream.rtpdump
OUTFILE=ipv4_converted.pcap
LOG=convert.log 
RTPTOOL_PATH=/usr/local/bin/
if [ $# -ne 2 ]; then
	echo "Error parsing command line arguments"
	echo "Usage:"
	echo "  $0 <rtpdump INFILE NAME> <ipv4 pcap OUTFILE NAME>"
	exit 0
fi
	INFILE=$1
	OUTFILE=$2

echo "Starting Convert of $INFILE to $OUTFILE" > $LOG

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

step "Starting RTP Listener"
$RTPTOOL_PATH/rtpdump 127.0.0.1/57344  &>> $LOG &
next

step "Starting IP Capture"
tcpdump -B20000 -ilo -s0 -w $OUTFILE udp port 57344 &>> $LOG &
next

step "Starting RTP Playback Conversion..."
$RTPTOOL_PATH/rtpplay -T -f $INFILE 127.0.0.1/57344 &>> $LOG
next

echo "Convert of $INFILE complete!, new file is $OUTFILE"
echo
