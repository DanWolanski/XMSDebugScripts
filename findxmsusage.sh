#! /bin/bash
######################################################################
#
# Dialogic(r) PowerMedia eXtended Media Server csv report parser
#
# Copyright (C) 2001-2018 Dialogic Corporation.  All Rights Reserved.
#
# All names, products, and services mentioned herein are the
# trademarks or registered trademarks of their respective
# organizations and are the sole property of their respective
# owners.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this sample software and associated documentation files 
# (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
# distribute, and /or sublicense the Software, and to permit persons to whom the Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# __Third Party Software__
#
# Third party software (e.g., drivers, utilities, operating system components, etc.) which may be distributed with the Software will also be
# subject to the terms and conditions of any third party licenses, which may be supplied with such third party software.
#
######################################################################
CSVFILES="/var/local/xms/xmscld/xms*.csv"
#CSVFILES="./xms*.csv"
CSVHEADER=$(cat $CSVFILES | grep timestamp | head -1)

OUTFILE="/var/log/xmsusage.json"

COLUMNS=(
" XMS Server Lic BA Active [MAX] "
" XMS Server Lic GSM-AMR Active [MAX] "
" XMS Server Lic HD-Voice Active [MAX] "
" XMS Server Lic LBR Active [MAX] "
" XMS Server Lic Adv-Video Active [MAX] "
" XMS Server Lic HR-Video Active [MAX] "
)
date=$(date)
host=$(hostname)

echo "{" >> ${OUTFILE}
echo "\"date\" : \"$date\" , " >> ${OUTFILE}
echo "\"host\" : \"$host\" ," >> ${OUTFILE}
for col in "${COLUMNS[@]}" ;
do
  colnum=$(echo "$CSVHEADER" | awk -F, '{ for (i=1; i < NF; ++i) if ($i == "'"$col"'") print i; }')
  maxval=$(cat $CSVFILES | grep -P "^20\d\d\d\d\d\d-" | cut -d"," -f $colnum | sort -nr | head -1)
  #echo "$col ($colnum) = $maxval"
  echo  "\"$col\" : \"$maxval\" ," >> ${OUTFILE}
done
echo "}," >> ${OUTFILE}



