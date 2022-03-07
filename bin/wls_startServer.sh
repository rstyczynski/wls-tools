#!/bin/bash

export DOMAIN_NAME=$1
export DOMAIN_HOME=$2
export NM_HOST=$3
export NM_PORT=$4
export MS_NAME=$5

# note = at the end of aes format
export AES_USERNAME="$(cat $DOMAIN_HOME/servers/AdminServer/security/boot.properties | grep username | cut -d= -f2)="
export AES_PASSWORD="$(cat $DOMAIN_HOME/servers/AdminServer/security/boot.properties | grep password | cut -d= -f2)="

source $DOMAIN_HOME/bin/setDomainEnv.sh 
# cat | $WLS_HOME/../../oracle_common/common/bin/wlst.sh <<EOF_wlst
cat | java weblogic.WLST <<EOF_wlst

try:
  ms_name=os.environ['MS_NAME']

  domain_home=os.environ['DOMAIN_HOME']
  domain_name=os.environ['DOMAIN_NAME']

  nm_host=os.environ['NM_HOST']
  nm_port=os.environ['NM_PORT']
except Exception, err:
  print('Error getting parameters.')
  print(err)
  exit(exitcode=1)

try:
  service = weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain_home)
  encryption = weblogic.security.internal.encryption.ClearOrEncryptedService(service)

  username=encryption.decrypt(os.environ['AES_USERNAME'])
  password=encryption.decrypt(os.environ['AES_PASSWORD'])
except Exception, err:
  print('Error decrypting credentials.')
  print(err)
  exit(exitcode=2)

try:
  nmConnect(username, password, nm_host, nm_port, domain_name, domain_home)
except Exception, err:
  print('Error connecting to node manager.')
  print(err)
  exit(exitcode=3)

try:  
  nmStart(ms_name)
except Exception, err:
  print('Error starting server.')
  print(err)
  exit(exitcode=4)

exit()
EOF_wlst
WLST_result=$?

exit $WLST_result

