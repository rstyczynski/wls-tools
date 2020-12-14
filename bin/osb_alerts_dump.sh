#!/bin/bash

cmd=$1
shift

case $cmd in
start)
    source ~/umc/bin/umc.h

    mkdir -p ~/.x-ray/stdout
    mkdir -p ~/.x-ray/pid
    
    cd $DOMAIN_HOME
    nohup $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_dump.wlst $@ > ~/.x-ray/stdout/osb_alerts_dump.out &
    cd -
    echo $! > ~/.x-ray/pid/osb_alerts_dump.pid
    ;;

stop)
    kill $(cat ~/.x-ray/pid/osb_alerts_dump.pid)
    rm -rf ~/.x-ray/pid/osb_alerts_dump.pid
    rm -rf ~/.x-ray/stdout/osb_alerts_dump.out
    ;;

status)
    if [ -f ~/.x-ray/pid/osb_alerts_dump.pid ]; then
        echo "Runnning at: $(cat ~/.x-ray/pid/osb_alerts_dump.pid)"
        tail  ~/.x-ray/stdout/osb_alerts_dump.out
    else
        echo "Not running."
    fi
    ;;
esac
