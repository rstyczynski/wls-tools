#!/bin/bash

DOMAIN_HOME=$1
ADMIN_URL=$2
WLS_NAME=$3

source $DOMAIN_HOME/bin/setDomainEnv.sh 
cd $DOMAIN_HOME
cat | java weblogic.WLST <<EOF_wlst
connect(url='$ADMIN_URL', adminServerName='AdminServer')
try:
  shutdown('$WLS_NAME','Server', 'true', 900, 'true')
except Exception, err:
  print('Error stopping server.')
  print(err)
  exit(exitcode=1)

disconnect()
exit()
EOF_wlst
WLST_result=$?

exit $WLST_result
