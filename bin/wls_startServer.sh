#!/bin/bash

DOMAIN_HOME=$1
ADMIN_URL=$2
WLS_NAME=$3

source $DOMAIN_HOME/bin/setDomainEnv.sh 
cd $DOMAIN_HOME
cat | java weblogic.WLST <<EOF_wlst
connect(url='$ADMIN_URL', adminServerName='AdminServer')
try:
  start('$WLS_NAME','Server')
except Exception, err:
  print('Error starting server.')
  print(err)
  exit(exitcode=1)

disconnect()
exit()
EOF_wlst
WLST_result=$?

exit $WLST_result

