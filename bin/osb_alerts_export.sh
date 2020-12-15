#!/bin/bash

function usage() {
    cat <<EOF
Usage: osb_alerts_export.sh today|yesterday|[previous no_of_days]

Alerts for each day are stored in ~/x-ray/diag/wls/alert/DOMAIN/SERVER/DATE directory.

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

function export_day() {
    to_date=$1; shift

    for osb_server in $OSB_SERVERS; do
        echo "OSB: $osb_server"

        mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date

        cd $DOMAIN_HOME
        
        $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_export.wlst \
        --url $ADMIN_URL \
        --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date \
        --osb $osb_server \
        --to_day $to_date \
        $@

        cd - >/dev/null
    done
}

cmd=$1; shift

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
OSB_CLUSTER=$(get_domain_config | xmllint --xpath "/domain/app-deployment/name[text()='Service Bus Message Reporting Purger']/../target/text()" -)
OSB_SERVERS=$(get_domain_config | xmllint --xpath "/domain/server/cluster[text()='$OSB_CLUSTER']/../name" - | sed 's|</*name>|;|g' | tr ';' '\n' | grep -v '^$')

ADMIN_PORT=$(get_domain_config | xmllint --xpath "/domain/server/name[text()='$ADMIN_NAME']/../listen-port" - | sed 's|</*listen-port>||g')
ADMIN_ADDRESS=$(get_domain_config | xmllint --xpath "/domain/server/name[text()='$ADMIN_NAME']/../listen-address" - | sed 's|</*listen-address>||g')
ADMIN_URL="t3://$ADMIN_ADDRESS:$ADMIN_PORT"


case $cmd in
today)
    export_day $(date -I)
    ;;
yesterday)
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