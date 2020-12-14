#!/bin/bash

parameters=$@

source ~/wls-tools/bin/discover_processes.sh 
discoverWLS

for srvNo in ${!wls_managed[@]}; do
    pid=$(getWLSjvmAttr ${wls_managed[$srvNo]} os_pid)
    lsof -p $pid | grep 'lib/apps/sbresource.war' > /dev/null
    if [ $? -eq 0 ]; then
        echo "OSB: ${wls_managed[$srvNo]}"

        MW_HOME=$(getWLSjvmAttr ${wls_managed[$srvNo]} mw_home)
        DOMAIN_HOME=$(getWLSjvmAttr ${wls_managed[$srvNo]} -Ddomain.home)
        DOMAIN_NAME=$(getWLSjvmAttr ${wls_managed[$srvNo]} domain_name)

        mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/${wls_managed[$srvNo]}/$(date -I)

        cd $DOMAIN_HOME
        
        $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_export.wlst \
        --url="t3://$( getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_name):$( getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_port)"
        --dir=$HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/${wls_managed[$srvNo]}/$(date -I) \
        --osb=${wls_managed[$srvNo]} \
        $parameters

        cd -
    fi
done
