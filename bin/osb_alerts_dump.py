#!/bin/python
# 
# !/u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh 


# dump previous 60 seconds
# 1. execute in a loop with 60 seconds wait time. 
# 1. 

import datetime
from datetime import datetime
import calendar
import time

import os


wlst = False

dst_dir='/tmp'

server_name='osb_server1'

DATname='CUSTOM/com.bea.wli.monitoring.pipeline.alert'

admin_url='t3://omcscbailqkcuh:3015'
admin_name='AdminServer'

safety_time_lag = 5  # program takes older messages to avoid message loosing or overlapping

def createFolder(directory):
    try:
        if not os.path.exists(directory):
            os.makedirs(directory)
    except OSError:
        print ('Error: Creating directory. ' +  directory)
        
if wlst:
    connect(url=admin_url, adminServerName=admin_name)

def export_osb_alerts(count=10, interval=5):

    startAt = calendar.timegm(time.gmtime()) - interval
    while count >0:
        #
        current_timestmap = calendar.timegm(time.gmtime())
        endAt = current_timestmap - safety_time_lag
        #
        dateISO=datetime.fromtimestamp(endAt).isoformat().split('T')[0]
        timeISO=datetime.fromtimestamp(endAt).isoformat().split('T')[1]
        #
        print "Exporting to " + dst_dir + "/" + dateISO + "/osb_alert." + timeISO + ".xml"
        print "  server       : " + server_name
        print "  current time : " + str(startAt * 1000L) + ", " + str(datetime.fromtimestamp(current_timestmap))
        print "  from         : " + str(startAt * 1000L) + ", " + str(datetime.fromtimestamp(startAt))
        print "  to           : " + str(endAt * 1000L) + ", " + str(datetime.fromtimestamp(endAt))
        #
        createFolder(dst_dir + "/" + dateISO)
        #
        #
        export_start = calendar.timegm(time.gmtime())
        if wlst:
            exportDiagnosticDataFromServer(logicalName=DATname, 
            exportFileName=dst_dir + "/" + dateISO + "/osb_alert." + timeISO + ".xml", 
            server=server_name, 
            beginTimestamp=PyLong(startAt), endTimestamp= PyLong(endAt))
        else:
            time.sleep(6)
        #
        export_stop = calendar.timegm(time.gmtime())
        #
        export_delay = export_stop - export_start
        #
        print "---"
        print "Export delay   : " + str(export_delay)
        print "---"

        wait_tme = interval - export_delay
        if wait_tme < 0:
            wait_tme = 0

        print "Waiting " + str(wait_tme) + "..."
        #
        if wlst:
            java.lang.Thread.sleep(wait_tme * 1000)
        else:
            time.sleep(wait_tme)
        #
        startAt = endAt + 1
        #
        count = count - 1
        #


export_osb_alerts(10, 5)
