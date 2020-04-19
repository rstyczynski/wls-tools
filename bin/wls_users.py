#!$BEA_HOME/oracle_common/common/bin/wlst.sh 

# default values
admin_name = 'AdminServer'
admin_address = 'localhost'
admin_port = 7001
admin_protocol = 't3'
admin_url = admin_protocol + "://" + admin_address + ":" + str(admin_port)


def usage():
    print "dump_users [-s|--server -p|--port] [-u|--url] [-d|--delimiter]"


try:
    opts, args = getopt.getopt( sys.argv[1:], 's:p:u::d:h', ['server=','port=','url=','delimiter='] )
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

for opt, arg in opts:
    if opt in ('--help'):
        usage()
        sys.exit(2)
    elif opt in ('-s', '--server'):
        admin_name = arg
    elif opt in ('-p', '--port'):
        admin_port = arg
        admin_url = admin_protocol + "://" + admin_address + ":" + str(admin_port)
    elif opt in ('-u', '--url'):
        admin_url = arg
    elif opt in ('-d', '--delimiter'):
        delimiter = arg
    else:
        usage()
        sys.exit(2)


connect(url=admin_url, adminServerName=admin_name)

# do work
from weblogic.management.security.authentication import UserReaderMBean
from weblogic.management.security.authentication import GroupReaderMBean
 
realmName=cmo.getSecurityConfiguration().getDefaultRealm()
authProvider = realmName.getAuthenticationProviders()
 
print 'admin_url,group,user'   
for i in authProvider:
  if isinstance(i,GroupReaderMBean):
    groupReader = i
    cursor =  i.listGroups("*",0)
    while groupReader.haveCurrent(cursor):
        group = groupReader.getCurrentName(cursor)   
        usergroup = i.listAllUsersInGroup(group,"*",0)
        for user in usergroup:
            print '%s,%s,%s' % (admin_url,group,user)
        groupReader.advance(cursor)
    groupReader.close(cursor)

#
disconnect()
exit()