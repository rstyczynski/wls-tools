#!/bin/bash

DOMAIN_HOME=$1
WLS_HOME=$2
ADMIN_URL=$3
WLS_NAME=$4

source $DOMAIN_HOME/bin/setDomainEnv.sh 
cd $DOMAIN_HOME

cat | $WLS_HOME/../../oracle_common/common/bin/wlst.sh <<EOF_wlst
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

