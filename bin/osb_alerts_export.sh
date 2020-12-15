#!/bin/bash

function usage() {
    cat <<EOF
Usage: osb_alerts_export.sh today|[previous no_of_days]

Alerts for each day are stored in ~/x-ray/diag/wls/alert/DOMAIN/SERVER/DATE directory.

EOF
}

function export_day() {
    to_date=$1; shift

    for srvNo in ${!wls_managed[@]}; do
        pid=$(getWLSjvmAttr ${wls_managed[$srvNo]} os_pid)
        lsof -p $pid | grep 'lib/apps/sbresource.war' > /dev/null
        if [ $? -eq 0 ]; then
            echo "OSB: ${wls_managed[$srvNo]}"

            MW_HOME=$(getWLSjvmAttr ${wls_managed[$srvNo]} mw_home)
            DOMAIN_HOME=$(getWLSjvmAttr ${wls_managed[$srvNo]} -Ddomain.home)
            DOMAIN_NAME=$(getWLSjvmAttr ${wls_managed[$srvNo]} domain_name)

            mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/${wls_managed[$srvNo]}/$to_date

            cd $DOMAIN_HOME
            
            $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_export.wlst \
            --url "t3://$( getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_name):$( getWLSjvmAttr ${wls_managed[$srvNo]} admin_host_port)" \
            --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/${wls_managed[$srvNo]}/$to_date \
            --osb ${wls_managed[$srvNo]} \
            --to_day $to_date \
            $@

            cd - >/dev/null
        fi
    done
}

cmd=$1; shift

source ~/wls-tools/bin/discover_processes.sh 
discoverWLS

case $cmd in
today)
    export_day $(date -I)
    ;;
yestarday)
    export_day $(date --date="1 days ago" -I)
    ;;
previous)
    days=$1; shift
    for day in $(seq 0 $days); do
        that_day=$(date --date="$day days ago" -I)
        echo "Exporting $that_day..."
        export_day $that_day
    done
    ;;
*)
    usage
    ;;
esac