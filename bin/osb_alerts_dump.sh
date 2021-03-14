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

function get_domain_param(){
    xpath=$1

    # truncates text nodes!!!
    #echo "xpath $xpath" | xmllint --shell <(get_domain_config) | grep content | cut -d= -f2

    get_domain_config | ~/tools/bin/xmllint --xpath "$xpath" -
}

cmd=$1
shift

case $cmd in
start)

    pid_files=$(ls ~/.x-ray/pid/osb_alerts_dump_*.pid 2>/dev/null)
    if [ ! -z "$pid_files" ]; then
        echo "Process already running. Use stop command before next start. Use status to discover what's up."
        exit 1
    fi

    source ~/wls-tools/bin/discover_processes.sh 
    discoverWLS

    if [ -z "${wls_admin[0]}" ]; then
        echo "Error. No admin server found. Cannot continue."
        exit 1
    fi


    ADMIN_NAME=${wls_admin[0]}
    MW_HOME=$(getWLSjvmAttr $ADMIN_NAME mw_home)
    DOMAIN_HOME=$(getWLSjvmAttr $ADMIN_NAME -Ddomain.home)
    DOMAIN_NAME=$(getWLSjvmAttr $ADMIN_NAME domain_name)

    # take OSB cluster, and osb servers
    OSB_CLUSTER=$(get_domain_param "/domain/app-deployment/name[text()='Service Bus Message Reporting Purger']/../target/text()")
    
    # xmlint return multiple rows as one - new line problem
    #OSB_SERVERS=$(get_domain_param "/domain/server/cluster[text()='$OSB_CLUSTER']/../name/text()")
    OSB_SERVERS=$(get_domain_param "/domain/server/cluster[text()='$OSB_CLUSTER']/../name" | sed 's|</*name>|;|g' | tr ';' '\n' | grep -v '^$')

    ADMIN_PORT=$(get_domain_param "/domain/server/name[text()='$ADMIN_NAME']/../listen-port/text()")
    ADMIN_ADDRESS=$(get_domain_param "/domain/server/name[text()='$ADMIN_NAME']/../listen-address/text()")
    ADMIN_URL="t3://$ADMIN_ADDRESS:$ADMIN_PORT"


    if [ -z "$DOMAIN_HOME" ]; then
        echo "Error. No WebLogic domain found. Cannot continue."
        exit 1
    fi

    mkdir -p ~/.x-ray/stdout
    mkdir -p ~/.x-ray/pid

    for osb_server in $OSB_SERVERS; do
        echo "OSB: $osb_server"

        mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$(date -I)

        cd $DOMAIN_HOME

        ( 
            nohup $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_dump.wlst \
            --url $ADMIN_URL \
            --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$(date -I) \
            --osb $osb_server \
            $@  >> ~/.x-ray/stdout/osb_alerts_dump_$osb_server.out 2>&1
            rm -rf ~/.x-ray/pid/osb_alerts_dump_$osb_server.pid
            # do not delete out files
            # rm -rf ~/.x-ray/stdout/osb_alerts_dump_$osb_server.out
        ) &
        echo $! > ~/.x-ray/pid/osb_alerts_dump_$osb_server.pid 

        cd - >/dev/null
    done
    ;;

stop)
    pid_files=$(ls ~/.x-ray/pid/osb_alerts_dump_*.pid 2>/dev/null)
    if [ ! -z "$pid_files" ]; then
        for pid_file in $pid_files; do
            echo "Process: $pid_file"
            ~/wls-tools/bin/killtree.sh $(cat $pid_file)
            rm -rf $pid_file
            echo "Stopped"
        done
        # do not delete out files
        # rm -rf ~/.x-ray/stdout/osb_alerts_dump_*.out
    else
        echo "Not running."
    fi
    ;;

status)

    pid_files=$(ls ~/.x-ray/pid/osb_alerts_dump_*.pid 2>/dev/null)
    if [ ! -z "$pid_files" ]; then
        echo "Runnning at: $(cat ~/.x-ray/pid/osb_alerts_dump_*.pid)"
        for log in $(ls ~/.x-ray/stdout/osb_alerts_dump_*.out); do
            echo "Log: $log"
            tail $log  
        done
    else
        echo "Not running."
    fi
    ;;
install_cron)

    source ~/wls-tools/bin/discover_processes.sh 
    discoverWLS

    if [ -z "${wls_admin[0]}" ]; then
        echo "Error. No admin server found. Cannot continue."
        exit 1
    fi

    ~/oci-tools/bin/install_cron_entry.sh add osb_alerts_dump 'OSB alert dump' '1 0 * * * $HOME/wls-tools/bin/osb_alerts_dump.sh stop; $HOME/wls-tools/bin/osb_alerts_dump.sh start'
    ;;

install_x-ray_sync)

    source ~/wls-tools/bin/discover_processes.sh 
    discoverWLS

    if [ -z "${wls_admin[0]}" ]; then
        echo "Error. No admin server found. Cannot continue."
        exit 1
    fi

    for osb_server in $OSB_SERVERS; do
        echo "OSB: $osb_server"

        export domain_name=$DOMAIN_NAME
        export wls_server=$osb_server
        ~/oci-tools/bin/tpl2data.sh ~/oci-tools/template/diagnose-osb_alerts.yaml > ~/.x-ray/diagnose-osb_alerts-${domain_name}_${osb_server}.yaml
    done
    ;;
*)
    usage
    ;;
esac
