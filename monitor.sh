#!/bin/bash
rm -f top-output.txt
rm -f sar-output.txt
rm -f ps-output.txt
rm -f tmptop.txt
rm -f tmpsar.txt
rm -f tmpps.txt
while true
do
        clear
        echo -e `date` "-" `hostname` "\n"
       echo -e "\nDisk/Mem Usage:"
      free -m
#       echo -e "\n"
#        df
       #echo -e "\n\n\nUptime:" `uptime`

        top -b -n 1 > tmptop.txt
        sar -A > tmpsar.txt
	echo -e `date` "----------------"  > tmpps.txt
	ps -A  -Lo %cpu,pid,lwp,comm=,args >> tmpps.txt
	echo -e "\n\nCPU Intensive Threads"
	grep '^ *[0-9][0-9][0-9]\.' tmpps.txt
        grep '^ *[2-9][0-9]\.' tmpps.txt
        echo -e "\n\nTop Info:"
        grep Cpu tmptop.txt | grep '[0-9][0-9]\.[0-9]%us'
        grep Mem: tmptop.txt
        grep Swap: tmptop.txt
	echo -e "\n"
	grep PID tmptop.txt
        grep ssp tmptop.txt
        grep msml tmptop.txt
        grep appmanager tmptop.txt
        grep xmserver tmptop.txt
        grep java tmptop.txt
	grep rest tmptop.txt

#        echo -e "\n\nMeters:"
#        grep xmsRtpSessions /var/lib/xms/meters/currentValue.txt
#        grep xmsSignalingSessions /var/lib/xms/meters/currentValue.txt
#        grep calls.active /var/lib/xms/meters/currentValue.txt
#        grep transactions.active /var/lib/xms/meters/currentValue.txt

#	mpstat -P ALL 1 | tee mpstats.txt

#       echo -e "\n\nNetwork Errors:"
#       tcpdump -i SIP -v -c 5000 | grep "SIP/2.0 4"
        cat tmptop.txt >> top-output.txt
        cat tmpsar.txt >> sar-output.txt
	cat tmpps.txt >> ps-output.txt
        cat /var/lib/xms/meters/currentValue.txt >> meters-output.txt
        sleep 5 
done

