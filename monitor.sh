#!/bin/bash


#start network capture 
# Comment out line with tcpdump if you don't want network tracing 
echo -e "Starting background network trace \n" 
rm -f tmp-network.txt
tcpdump -i any -v port 5060 | grep -P "SIP/2.0 [4|5]" > tmp-network.txt &

while true
do
       LOOPCOUNTER=0
       echo 'Clearing temp files'
       rm -f tmptop.txt
       rm -f tmpps.txt
       rm -f top-output.txt
       rm -f ps-output.txt
       rm -f meters-output.txt
       rm -f topthreads-output.txt

       starttime=`date +"%y-%m-%d_%H:%M:%S.%3N"`
       hostname=`hostname`
       #will do the compress every ~10mins
       while [ $LOOPCOUNTER -lt 120 ]; do
       let LOOPCOUNTER=LOOPCOUNTER+1
       clear
       looptimestamp=`date +"%y-%m-%d_%H:%M:%S.%3N"`
       echo -e $looptimestamp "-" $hostname [$LOOPCOUNTER]"\n"
       echo -e "\nDisk/Mem Usage:"
       free -m
       #echo -e "\n"
       # df
       #echo -e "\n\n\nUptime:" `uptime`
	   #echo -e "\nXMS Cache file count:"
	   #echo `ls -l /var/cache/xms/http/xmserver/ | wc -l`

        top -b -n 1  > tmptop.txt
        
	    echo -e $looptime stamp "----------------"  > tmpps.txt
	    ps -A  -Lo %cpu,pid,lwp,comm=,args >> tmpps.txt
	    
        echo -e "\n\nCPU Intensive Threads"
	    grep '^ *[0-9][0-9][0-9]\.' tmpps.txt
        grep '^ *[2-9][0-9]\.' tmpps.txt
        echo -e "\n\nTop Info:"
        grep Cpu tmptop.txt 
        grep Mem: tmptop.txt
        grep Swap: tmptop.txt
	    echo -e "\n"
	    grep PID tmptop.txt
        grep ssp tmptop.txt
        grep appmanager tmptop.txt
        grep xmserver tmptop.txt
        
        #these can be commended out based on tech used
        grep msml tmptop.txt
        grep vxml tmptop.txt
        grep rest tmptop.txt
        grep netann tmptop.txt
        
        grep httpclient tmptop.txt

        #used by mrb/lb
        grep java tmptop.txt
        
        #Alternatively you can use
        #top -n 1 -b | head -20

	    
        echo -e "\n\nMeters(if available):"
        grep xmsRtpSessions /var/lib/xms/meters/currentValue.txt
        grep xmsSignalingSessions /var/lib/xms/meters/currentValue.txt
#        grep calls.active /var/lib/xms/meters/currentValue.txt
#        grep transactions.active /var/lib/xms/meters/currentValue.txt

#	mpstat -P ALL 1 | tee mpstats.txt

        if [ -f tmp-network.txt ] ;
        then
            echo -e "\nNetwork Error count:" + `wc -l tmp-network.txt` + "\n"
            #cat tmp-network.txt
            cat /dev/null > tmp-network.txt
        fi
        
        echo -e  "$looptime-$hostname\n" >> top-output.txt
        cat tmptop.txt >> top-output.txt
        echo -e  "$looptime-$hostname\n" >> ps-output.txt
	    cat tmpps.txt >> ps-output.txt
        echo -e "$looptime-$hostname\n" >> meters-output.txt
        cat /var/lib/xms/meters/currentValue.txt >> meters-output.txt
       
        echo -e  "$looptime-$hostname\n" >> topthreads-output.txt
        top -b -n 1 -H >> topthreads-output.txt
	
        rm -f tmptop.txt
        rm -f tmpps.txt
	
        echo -e "\n\n"
        sleep 5 
        done
	sar -A > sar-output.txt
	tar cvzf monitor-$starttime.tgz *-output.txt
    #delete files over 2 days old   
    find . -name 'monitor-*.tgz' -mtime +3 -delete
done
