#!/bin/bash

all_params=$@

if [ -z $all_params ]; then
   echo "No parameters specified. Trying main ip address with default port." >&2
   all_params="--url=http://$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f7):7001"
fi

script_dir="$( cd "$( dirname "$0" )" && pwd )"
script=$script_dir/wls_users.py

domain_home=$(ps ux | grep java | grep AdminServer | tr ' ' '\n' | grep domain.home | cut -f2 -d=)
if [ -f $domain_home/bin/setDomainEnv.sh ];then
   source $domain_home/bin/setDomainEnv.sh >%2
else
   echo "Error. AdminServer not running on this host. Cannot continue."
   exit 1
fi

echo "Starting $BEA_HOME/oracle_common/common/bin/wlst.sh $script $all_params ..." >&2

cd $DOMAIN_HOME
$BEA_HOME/oracle_common/common/bin/wlst.sh $script $all_params | egrep --line-buffered -v 'CLASSPATH|Jython scans all the jar files it can find at first startup. Depending on the system, this process may take a few minutes to complete, and WLST may not return a prompt right away.|Initializing WebLogic Scripting Tool|Welcome to WebLogic Server Administration Scripting Shell|Type help\(\) for help on available commands|Connecting to|Successfully connected to|Warning: An insecure protocol was used to connect to the|To ensure on-the-wire security|Admin port should be used instead|Disconnected from weblogic server|Exiting WebLogic Scripting Tool|Location changed to domainRuntime tree. This is a read-only tree with DomainMBean as the root.|For more help, use help\(domainRuntime\)|Already in Domain Runtime Tree|^$' 
cd - >/dev/null