#!/bin/bash

function usage() {
    cat <<EOF
Usage: osb_alerts_dump.sh [start [--count] [--interval]] | stop | status

Alerts are stored in ~/x-ray/diag/wls/alert/DOMAIN/SERVER/DATE directory.

EOF
}

function get_domain_config() {
    #prepare config.xml
    cat $DOMAIN_HOME/config/config.xml |
        xmllint --format - |
        sed -e 's/xmlns=".*"//g' | # remove namespace definitions
        sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
        sed -E 's/nil="\w+"//g' |  # remove nil="true"
        perl -pe 's/xsi:type="[\w:-]*"//g' |  # remove xsi:type="
        perl -pe 's/xsi:nil="[\w:-]*"//g' |  # remove nxsi:nil=
        perl -pe 's/<\w+://g' |  # remove nxsi:nil=
        perl -pe 's/<\/\w+://g' |  # remove nxsi:nil=
        cat | xmllint --exc-c14n - 
}

cmd=$1
shift

case $cmd in
start)

    source ~/wls-tools/bin/discover_processes.sh 
    discoverWLS

    if [ -z "${wls_admin[0]}" ]; then
        echo "Error. No admin server found. Cannot continue."
        exit 1
    fi

    MW_HOME=$(getWLSjvmAttr ${wls_admin[0]} mw_home)
    DOMAIN_HOME=$(getWLSjvmAttr ${wls_admin[0]} -Ddomain.home)
    DOMAIN_NAME=$(getWLSjvmAttr ${wls_admin[0]} domain_name)

    # take OSB cluster, and osb servers
    OSB_CLUSTER=$(get_domain_config | xmllint --xpath "/domain/app-deployment/name[text()='Service Bus Message Reporting Purger']/../target/text()" -)
    OSB_SERVERS=$(get_domain_config | xmllint --xpath "/domain/server/cluster[text()='$OSB_CLUSTER']/../name" - | sed 's|</*name>|;|g' | tr ';' '\n' | grep -v '^$')

    mkdir -p ~/.x-ray/stdout
    mkdir -p ~/.x-ray/pid

    for osb_server in $OSB_SERVERS; do
        echo "OSB: $osb_server"

        mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$(date -I)

        cd $DOMAIN_HOME

        nohup $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_dump.wlst \
        --url "t3://$(getWLSjvmAttr $osb_server admin_host_name):$(getWLSjvmAttr $osb_server admin_host_port)" \
        --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$(date -I) \
        --osb ${wls_managed[$srvNo]} \
        $@  > ~/.x-ray/stdout/osb_alerts_dump.out > ~/.x-ray/stdout/osb_alerts_dump_${wls_managed[$srvNo]}.out &
        echo $! > ~/.x-ray/pid/osb_alerts_dump_${wls_managed[$srvNo]}.pid            

        cd - >/dev/null
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
*)
    usage
    ;;
esac
