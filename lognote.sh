#!/bin/bash


TIMESTAMP=`date  +'%Y-%m-%d %H:%M:%S.%s' `
for f in /var/log/xms/*.log /var/log/dialogic/rtf*.txt /var/log/messages
do
        echo $TIMESTAMP LOGNOTE  $@ >> $f
done
