#!wlst

import datetime
from datetime import datetime
import calendar
import time as pytime

import os


wlst = True

DATname='CUSTOM/com.bea.wli.monitoring.pipeline.alert'

def dump_osb_alerts(count=1, interval=0):

    startAt = calendar.timegm(pytime.gmtime()) - interval
    while count >0:
        #
        current_timestmap = calendar.timegm(pytime.gmtime())
        endAt = current_timestmap - safety_lag
        #
        dateISO=datetime.fromtimestamp(endAt).isoformat().split('T')[0]
        timeISO=datetime.fromtimestamp(endAt).isoformat().split('T')[1]
        #
        print "Exporting to " + dst_dir + "/osb_alert." + dateISO + "T" + timeISO + ".xml"
        print "  server       : " + server_name
        print "  current time : " + str(startAt * 1000L) + ", " + str(datetime.fromtimestamp(current_timestmap))
        print "  from         : " + str(startAt * 1000L) + ", " + str(datetime.fromtimestamp(startAt))
        print "  to           : " + str(endAt * 1000L) + ", " + str(datetime.fromtimestamp(endAt))
        #
        export_start = calendar.timegm(pytime.gmtime())
        if wlst:
            exportDiagnosticDataFromServer(logicalName=DATname, 
            exportFileName=dst_dir + "/osb_alert." + dateISO + "T" + timeISO + ".xml", 
            server=server_name, 
            beginTimestamp=PyLong(startAt), endTimestamp= PyLong(endAt))
        else:
            time.sleep(6)
        #
        export_stop = calendar.timegm(pytime.gmtime())
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


dst_dir='/tmp'
server_name='osb_server1'
admin_name='AdminServer'

safety_lag = 5  # program takes older messages to avoid message loosing or overlapping

count = 288 # 24 hours with 
delay = 300 # 5 miutes interval

try:
    opts, args = getopt.getopt( sys.argv[1:], '', ['admin=','port=','url=', 'help', 'count=', 'delay=', 'dir=', 'osb=', 'safety_lag=' ] )
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)
	
for opt, arg in opts:
    if opt in ('--help'):
        usage()
        sys.exit(2)
    elif opt in ('--admin'):
        admin_name = arg
    elif opt in ('--port'):
        admin_port = arg
        admin_url = admin_protocol + "://" + admin_address + ":" + str(admin_port)
    elif opt in ('--url'):
        admin_url = arg
    elif opt in ('--dir'):
        dst_dir = arg
    elif opt in ('--osb'):
        server_name = arg
    elif opt in ('--count'):
        count = int(arg)
    elif opt in ('--delay'):
        delay = int(arg)
    elif opt in ('--safety_lag'):
        safety_lag = int(arg)
    else:
        usage()
        sys.exit(2)

if wlst:
    connect(url=admin_url, adminServerName=admin_name)

dump_osb_alerts(count, delay)
