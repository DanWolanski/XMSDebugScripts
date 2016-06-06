# XMSDebugScripts
This is a set of scripts and debug tools that can be used to troubleshoot XMS Support issues

### XMSInfo / XMSInfo_lite
    These are two scripts that can be used to assist in collecting data for new issues or as part of regular checkups on the system.
    The main difference in the two is that the lite script will not pull all of the WebUI data and will not include several of the XMS/Dialogic logs. This was done to speed up collection time and filesize.
    To run just run the executable
   ``` bash
    ./xmsinfo.sh
    ./xmsinfo_lite.sh
    ```
    Each will make a tgz with the output. You can find some useful system level information in the additionalinfo.out, some performance data in the toplog.out or the the sar.out. You can get some details on cache size and media files. Lastly you can get the messages file for offline review

### MONITOR
    This script will monitor system performance and usage information. This can be used as a check console, or it can be let running and save the data to file
    To view in window just run
    ``` bash
    ./monitor.sh
    ```
    To save to file run via
    ``` bash
    nohup ./monitor.sh > /dev/null &
    ```
    This too will keep 7 days worth of performance data

### GenXMSCores
    This will force the cores for all the XMS processes and HMP core components.
    This can be used to collect state in case of hang or state issue.
    This can be run directly
    ``` bash
    ./genXMSCores.sh
    ```
    You should also include xmsinfo and monitor output if possible with the cores.

### FailureWatchdog
    This script will monitor for several error conditions.  It will then restart and/or collect data automaticly

### Script-gracefulRestart/Shutdown
    These are a set of scripts that can be used to shutdown/restart the services gracefully
    The scripts will
    -Reset the Graceful shutdown timer
    -Issue CURL to set XMS out of service
    -Wait for system to stop
    -stop the nodecontroller
    -clear out the cache files
    -restart the services
    _Note: Shutdown doesn't include 6, but includes others_
    
    These scripts are used in a number of ways. They are used by the tech team to shudown and restart the servers. Also, they are used via the watchdog timer.
    To use just call it from the shell
    ``` bash
    ./gracefulShutdown.sh
    ```
### CacheClear and CacheClearandDisable
    Script to clear out the files left in the cache by crashes and other tasks. This will also disable the http caching.
    Was used to work around the delay in playback issue. Cache should remain disabled and clear is not baked into the gracefulRestart scripts. However, mentioning it for historical resons in case they startup a new MRF
    To run execute
    ``` bash
    ./clearanddisable.sh
    ```
### ErrorAndRestart Checker
    This script is used to search though the messages file for error triggers and report them.
    One and done errors (seen once indicates errors)
    - Threshold errors where you need x in y messages to trigger
    - Watch strings that will report but not count as error
    - Restart counters
    - It supports a few different types of detects
    To run this you can just issue
    ``` bash
    ./errorandrestartchecker.pl var/log/messages
    ```
    The output looks like this
    ``` bash
    Opening pvm1mrf1\var\log\messages-20160501 for parsing....
    Apr 25 18:38:29 pvm1mrf1 -Error Detected via threshold
    Apr 25 19:41:53 pvm1mrf1 -Restart detected (Recovering from Error)
    Apr 27 23:02:17 pvm1mrf1 -Restart detected (NOT restarting due to Error)
    Apr 27 23:10:40 pvm1mrf1 -Restart detected (NOT restarting due to Error)
    Apr 29 13:54:11 pvm1mrf1 -Restart detected (NOT restarting due to Error)
    Apr 29 21:18:44 pvm1mrf1 -Error Detected via ADEC<1142> could not write packet
    Apr 30 09:52:09 pvm1mrf1 -Restart detected (Recovering from Error)
    Apr 30 20:50:20 pvm1mrf1 -Error Detected via threshold
    Apr 30 21:34:02 pvm1mrf1 -Restart detected (Recovering from Error)
    230218 lines parsed
    SNMP trap count = 59
    Watch count = 0
    Fail count = 3
    Recovery count = 0
    Restart count = 6
    Current state is NO ERROR
    ```
    
### Appman Log Parser
    This script will search though appman for any list of regex strings. Then call sessions that match that string will be separated out into their own file.
    You can quickly extract call flows based on callID, error codes, filenames etc
    
    Note running with no command line args will break the file up in to all the sessions in their own file. If you do this for production logs you will generate thousands of files
    Ex, say you see an error in call ID 6e76335c-7e0c-4485-bccc-5845d8e53764, calling
    `appmanLogExtractor.pl 6e76335c-7e0c-4485-bccc-5845d8e53764`
    
    Simarly you can put multiple call ids, error codes to match (they are or relationship).
    This is good if you have a failed file you want to check where it was from, trace call IDs, pull out all calls with same error etc.

### Dump WebUI
    This script will dump out the contents of the WebUI via the REST API
    
### genbtfromcores
    This can be executed to automaticly generate the Backtrace from the a collection of cores.  This is useful to run to provide some information if the core files are too large to transfer
    
### Matcher
    This script will match 2 strings keeping a running total of the count.  Useful for determining leaks and matching starts/stops, opens closed etc
    
### AutoGenComments
    This will search though a log and highlight frequently viewed content
    
### AutoPullComments
    This will extract the comments from the autoGenComments of ones that are hand tagged
    
### metersCSVExtractor.pl
metersCSVExtractor.pl basicaudio amraudio xmsRtpSessions xmsSignalingSessions xmsMediaTransactions msrp.active.session

You don’t need the full names, just enough to ensure they are unique and remember they are case sensitive.

This will generate out a meters.csv file with the values from each
