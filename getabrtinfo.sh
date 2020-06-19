#!/bin/bash

echo "Listing:"
ls -altr /var/tmp/abrt

echo "last-ccpp:"
cat /var/tmp/abrt/last-ccpp
echo ""

for filename in /var/tmp/abrt/*; do
if [ -d $filename ]
then
	echo "======================== START ================================"
	echo "$filename"
	echo "==============================================================="
        echo "                     EXECUTABLE                                "
	echo "---------------------------------------------------------------"
	cat $filename/executable
	echo ""
	echo "---------------------------------------------------------------"
        echo "                      REASON                                   "
	echo "---------------------------------------------------------------"
	cat $filename/reason
	echo ""
	echo "---------------------------------------------------------------"
        echo "                     BACKTRACE                                 "
	echo "---------------------------------------------------------------"
	cat $filename/core_backtrace
	echo ""
	echo "==============================================================="
        echo "$filename"
	echo "=====================i===  END  ==============================="
fi
done


