#!/bin/bash

echo Generated via btdumpscript.sh > corebtinfo.log
echo Core List in dir - >> corebtinfo.log 
echo `ls -al ./core.*` >> corebtinfo.log
echo ------------------------------- >> corebtinfo.log
for corefile in ./core.*
do

	echo ============================= NEXT {$corefile}  ========================================== >> corebtinfo.log
	exe= `file ${corefile} | grep -oE  "'.*?'" | cut -c 2- | rev | cut -c2- | rev `
	echo ---------------------------------------------------------------------------- >> corebtinfo.log
	echo `ls -al $corefile` >> corebtinfo.log
	echo `file $corefile` >> corebtinfo.log
	echo ---------------------------------------------------------------------------- >> corebtinfo.log
	echo BT only >> corebtinfo.log
	echo ---------------------------------------------------------------------------- >> corebtinfo.log
	gdb --batch --quiet -ex "bt " -ex "quit" -core ${corefile} ${exe} 2>&1 >>  corebtinfo.log
	echo ---------------------------------------------------------------------------- >> corebtinfo.log
	echo FULL trace on all threads  >> corebtinfo.log
	echo ---------------------------------------------------------------------------- >> corebtinfo.log
	gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" -core ${corefile} ${exe} 2>&1 >>  corebtinfo.log
done

	echo ============================= DONE  ========================================== >> corebtinfo.log
echo -------------------------
echo corebtinfo.log generated!
echo -------------------------
