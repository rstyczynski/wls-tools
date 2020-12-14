#!/bin/bash

cmd=$1
shift

case $cmd in
start)

    source ~/wls-tools/bin/discover_processes.sh 
    discoverWLS

    mkdir -p ~/.x-ray/stdout
    mkdir -p ~/.x-ray/pid

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

            nohup $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_dump.wlst \
            --url "t3://$(getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_name):$( getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_port)" \
            --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/${wls_managed[$srvNo]}/$(date -I) \
            --osb ${wls_managed[$srvNo]} \
            $@  > ~/.x-ray/stdout/osb_alerts_dump.out > ~/.x-ray/stdout/osb_alerts_dump_${wls_managed[$srvNo]}.out &
            echo $! > ~/.x-ray/pid/osb_alerts_dump_${wls_managed[$srvNo]}.pid            

            cd - >/dev/null
        fi
    done
    ;;

stop)
    kill $(cat ~/.x-ray/pid/osb_alerts_dump_*.pid)
    rm -rf ~/.x-ray/pid/osb_alerts_dump_*.pid
    rm -rf ~/.x-ray/stdout/osb_alerts_dump_*.out
    ;;

status)
    if [ -f ~/.x-ray/pid/osb_alerts_dump_*.pid ]; then
        echo "Runnning at: $(cat ~/.x-ray/pid/osb_alerts_dump_*.pid)"
        for log in $(ls ~/.x-ray/stdout/osb_alerts_dump_*.out); do
            echo "Log: $log"
            tail $log  
        done
    else
        echo "Not running."
    fi
    ;;
esac
