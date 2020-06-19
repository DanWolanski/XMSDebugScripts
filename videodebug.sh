#!/bin/bash

if [ $# -eq 1 ]; then

logger -t videodebug 'Enabling Video debugging via script file'

export VIDEO_QUALITY_ISSUE_LOGGING_ENABLE=1
#C166269
export MMRSC_FFMPEG_RECORD_AUDIO=1
export MMRSC_FFMPEG_RECORD_VIDEO=1
export MMRSC_FFMPEG_FRAME_WRITE=1
export MMRSC_ENABLE_DEBUG_RECVID=1

export PIO_ENABLE_PACKET_PRINT=1
export PLR_ENABLE_PACKET_PRINT=1

#MRB=521
#export MDRSC_LOG_CODERINFO=1
#export VDEC_INP_DBG=1
#export VDEC_DEPACK_INP_DBG=1
#export VENC_OUT_DBG=1
#export MMRSC_FFMPEG_RECORD_AUDIO=1
#export RTP_ENABLE_DEBUG_RTCP_NACK=1
#export RTP_ENABLE_DEBUG_RTCP_PLI=1

ENABLED=$(env | grep 'VIDEO_QUALITY\|MDRS\|VDEC\|VENC\|MMRSC\|RTP\|PIO\|PLR')
logger -t videodebug "Enabled ${ENABLED}"


#logger -t videodebug "Enabling INGRESS and EGRESS packet loss (2%)"
#export RTP_ENABLE_INGRESS_PACKET_LOSS_SIM=2
#export RTP_ENABLE_EGRESS_PACKET_LOSS_SIM=2

#ENABLED=$(env | grep 'PACKET_LOSS_SIM')
#logger -t videodebug "Enabled ${ENABLED}"

fi
