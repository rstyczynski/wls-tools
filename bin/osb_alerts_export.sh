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

function get_domain_param(){
    xpath=$1

    # truncates text nodes!!!
    #echo "xpath $xpath" | xmllint --shell <(get_domain_config) | grep content | cut -d= -f2

    get_domain_config | ~/tools/bin/xmllint --xpath "$xpath" -
}

function export_day() {
    to_date=$1; shift

    for osb_server in $OSB_SERVERS; do
        echo -n "OSB: $osb_server..."

        mkdir -p ~/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date

        cd $DOMAIN_HOME
        
        $MW_HOME/oracle_common/common/bin/wlst.sh ~/wls-tools/bin/osb_alerts_export.wlst \
        --url $ADMIN_URL \
        --dir $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date \
        --osb $osb_server \
        --to_day $to_date \
        $@ | tee $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date/osb_alerts_export.log
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            rm -f $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date/osb_alerts_export.log
            echo OK
        else
            echo Error. Details: $HOME/x-ray/diag/wls/alert/$DOMAIN_NAME/$osb_server/$to_date/osb_alerts_export.log
        fi

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
install_cron)

    ~/oci-tools/bin/install_cron_entry.sh add osb_alerts_export "osb alert export" "2 0 * * * $HOME/wls-tools/bin/osb_alerts_export.sh yesterday"
    ;;

install_x-ray_sync)

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