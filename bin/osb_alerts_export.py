#!wlst

from datetime import datetime, timedelta
import time as pytime

wlst = True

DATname='CUSTOM/com.bea.wli.monitoring.pipeline.alert'

def export_osb_alerts(startDate, endDate):
    #
    startAt = pytime.mktime(startDate.timetuple())
    endAt=pytime.mktime(endDate.timetuple())
    #
    print "Exporting to " + dst_dir + "/osb_alert.xml"
    print "  server       : " + server_name
    print "  current time : " + str(current_timestmap) + ", " + str(datetime.fromtimestamp(current_timestmap))
    print "  from         : " + str(startAt) + ", " + str(datetime.fromtimestamp(startAt))
    print "  to           : " + str(endAt) + ", " + str(datetime.fromtimestamp(endAt))
    #
    if wlst:
        exportDiagnosticDataFromServer(logicalName=DATname, 
        exportFileName=dst_dir + "/osb_alerts.xml", 
        server=server_name, 
        beginTimestamp=PyLong(startAt * 1000L), endTimestamp= PyLong(endAt * 1000L))
    else:
        time.sleep(6)

dst_dir='/tmp'
server_name='osb_server1'
admin_name='AdminServer'

try:
    opts, args = getopt.getopt( sys.argv[1:], '', ['server=','port=','url=', 'help', 'from=', 'to=', 'dir=', 'osb=' ] )
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)
	
for opt, arg in opts:
    if opt in ('--help'):
        usage()
        sys.exit(2)
    elif opt in ('--server'):
        admin_name = arg
    elif opt in ('--port'):
        admin_port = arg
        admin_url = admin_protocol + "://" + admin_address + ":" + str(admin_port)
    elif opt in ('--url'):
        admin_url = arg
    elif opt in ('--from'):
        parts=arg.split('-')
        startDate = datetime(int(parts[2]), int(parts[1]), int(parts[0]))
        endDate = startDate + timedelta(days=1)
    elif opt in ('--to'):
        endDate = datetime.strptime(arg, '%d-%m-%Y')
    elif opt in ('--dir'):
        dst_dir = arg
    elif opt in ('--osb'):
        server_name = arg
    else:
        usage()
        sys.exit(2)

if wlst:
    connect(url=admin_url, adminServerName=admin_name)

export_osb_alerts(startDate, endDate)
