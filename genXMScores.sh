#!/bin/bash 

./xmsinfo.sh

mkdir xmscores

#XMS Core processes
gcore -o ./xmscores/xmserver_core `pidof xmserver`
gcore -o ./xmscores/appmanager `pidof appmanager`
gcore -o ./xmscores/broker `pidof broker`
gcore -o ./xmscores/eventmanager `pidof eventmanager`
gcore -o ./xmscores/nodecontroller `pidof nodecontroller`

#WebRTC process
gcore -o ./xmscores/rtcweb `pidof rtcweb`

#HMP Core process
gcore -o ./xmscores/ssp_x86Linux_boot `pidof ssp_x86Linux_boot`


#XMS interface processes
#gcore -o ./xmscores/vxmlinterpreter `pidof vxmlinterpreter`
#gcore -o ./xmscores/xmsrest `pidof xmsrest`
gcore -o ./xmscores/msml_main `pidof msmlserver`
#gcore -o ./xmscores/netann `pidof netann`

tar cvzf ./xmscores/binaries.tgz /usr/dialogic/bin/ssp_x86Linux_boot /usr/bin/xmserver /usr/bin/appmanager /usr/bin/broker /usr/bin/eventmanager /usr/bin/nodecontroller /usr/bin/rtcweb /usr/bin/vxmlinterpreter /usr/bin/xmsrest /usr/bin/msmlserver /usr/bin/netann


tar cvzf xmscores.tgz xmscores xmsinfo.tgz

