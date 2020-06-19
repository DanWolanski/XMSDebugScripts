#!/bin/bash 
 
CREATESTREAMFAIL="^(.*)appmanager:.*AppManager::onAckCreateStream.*failed to create stream, rejecting call.*"
MEDIAFAIL="^(.*)xmserver:.*ERROR  MediaServer::onCreateStream.*Media not available.*"
ADECERROR="^(.*)ssp_x86Linux_boot: ADEC.* could not write packet to .*"

FILETOTRACE="/var/log/messages"


( tail -F -n0 $FILETOTRACE & ) | grep -q -P "$MEDIAFAIL|$CREATESTREAMFAIL|$ADECERROR" 

