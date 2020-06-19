#!/usr/bin/env python
import sys
import urllib
import urllib2
import re
import json
import time
from datetime import datetime, date, time, timedelta
import syslog

timeout = 60

if len(sys.argv) > 1:
   timeout = int(sys.argv[1])

print "Checking CDR for calls older then %d mins" % timeout

request_headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8'
}

url = 'http://127.0.0.1:10080'
parms = '?pageNum=1&proto=SIP&callState=answered,connected'
request = urllib2.Request(url+'/cdr/query/run'+parms, headers=request_headers)
response = urllib2.urlopen(request).read()

#print(response)
resp = json.loads(response)
cdr_data = resp['queryData']
cdr_list = cdr_data['cdrArray']

cdr_size = cdr_data['cdrCount']

#print(cdr_list)
count = 0
now = datetime.now()
#print "Now is %s" % now

for cdr in cdr_list: 
   count += 1
   #print "CDR %d of %d" % (count,cdr_size)
   #print "%r " % record
   starttime = cdr['callStartTime']
   starttime = starttime[0:19] 
   callId = cdr['callId']
   print "CDR %d/%d:  %s @ %s" % (count,cdr_size,callId, starttime)
   
   st = datetime.strptime(starttime,"%Y-%m-%d %H:%M:%S")
   durration = now - st
   if durration > timedelta(minutes=timeout): 
      print "        *** This an old call (%s) - Terminating ***" % durration
      syslog.syslog('Terminating - CallId = %s , durration = %s' % (callId,durration))
      parms = '?callId=%s' % callId
      request = urllib2.Request(url+'/cdr/query/terminatecall'+parms, headers=request_headers)
      response = urllib2.urlopen(request).read()
      #print(response)



