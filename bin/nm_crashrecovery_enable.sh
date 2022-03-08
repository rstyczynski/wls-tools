#!/bin/bash

function enable_nm_CrashRecoveryEnable() {
  source $script_dir/config.sh 
  DOMAIN_HOME=$(getcfg $config_id DOMAIN_HOME 2>/dev/null)
  DOMAIN_OWNER=$(getcfg $config_id DOMAIN_OWNER 2>/dev/null)

  if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ]; then
    echo "Error. Domain home and domain owner not known."
    exit 1
  fi

  cfg_cmd="sed -i 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/' $DOMAIN_HOME/nodemanager/nodemanager.properties"

  if [ $(whoami) != $DOMAIN_OWNER ]; then
      sudo su - $DOMAIN_OWNER -c "$cfg_cmd"
      sudo su - $DOMAIN_OWNER -c "cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep CrashRecoveryEnabled"
  else
      $cfg_cmd
      cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep CrashRecoveryEnable
  fi
}

config_id=$1
shift
: ${config_id:=wls1}

# use cd to eliminate potentially relative path. we need the absolute one.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script_name=$(basename "${BASH_SOURCE[0]}")

enable_nm_CrashRecoveryEnable
exit $?
