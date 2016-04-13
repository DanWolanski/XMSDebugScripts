#!/bin/bash

starttime=`date +"%Y-%m-%d_%H-%M-%S"`
coredir="xmscores-$starttime"

mkdir $coredir

#XMS Core processes
gcore -o ./$coredir/xmserver_core `pidof xmserver`
gcore -o ./$coredir/appmanager `pidof appmanager`
gcore -o ./$coredir/broker `pidof broker`
gcore -o ./$coredir/eventmanager `pidof eventmanager`
gcore -o ./$coredir/nodecontroller `pidof nodecontroller`


#WebRTC process
gcore -o ./$coredir/rtcweb `pidof rtcweb`


#HMP Core process
gcore -o ./$coredir/ssp_x86Linux_boot `pidof ssp_x86Linux_boot`

#XMS interface processes
#gcore -o ./$coredir/vxmlinterpreter `pidof vxmlinterpreter`
#gcore -o ./$coredir/xmsrest `pidof xmsrest`
gcore -o ./$coredir/msml_main `pidof msmlserver`
#gcore -o ./$coredir/netann `pidof netann`

#copy of the binaries
tar cvzf ./$coredir/binaries.tgz /usr/dialogic/bin/ssp_x86Linux_boot /usr/bin/xmserver /usr/bin/appmanager /usr/bin/broker /usr/bin/eventmanager /usr/bin/nodecontroller /usr/bin/rtcweb /usr/bin/vxmlinterpreter /usr/bin/xmsrest /usr/bin/msmlserver /usr/bin/netann 

echo "----------------------------------------------------------------"
echo  Cores available in $coredir 
echo "----------------------------------------------------------------"
