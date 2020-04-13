#!/bin/bash

##
## shared functions
##
function utc::now() {
    date -u +"%Y-%m-%dT%H:%M:%S.000Z"
}

##
## specialized functions
##

function documentWLS() {
    local wls_name=$1

    if [ -z "$wlsdoc_now" ]; then
        echo "Required parameter not known: wlsdoc_now."
        return 1
    fi
    if [ -z "$wls_name" ]; then
        echo "Provide wls server name."
        return 1
    fi

    oldDst=$dst

    echo "*** WebLogic server discovery started"
    domain_name=$(getWLSjvmAttr $wls_name domain_name)

    dst=$wlsdoc_now/$domain_name/servers/$wls_name
    mkdir -p $dst

    echo -n ">> top level information..."
    printAttrGroup $wls_name info >$dst/info
    echo "Completed."

    echo -n ">> jvm details..."
    dst=$wlsdoc_now/$domain_name/servers/$wls_name/jvm
    mkdir -p $dst

    # jvm version
    $(getWLSjvmAttr $wls_name java_bin) -version >$dst/version 2>&1

    # jvm arguments
    rm -f $dst/args
    for group in $(getWLSjvmGroups $wls_name); do
        printAttrGroup $wls_name $group >>$dst/args
    done
    echo "Completed."

    echo "*** WebLogic server discovery done."
    dst=$oldDst
}

function documentMW() {
    local wls_name=$1

    if [ -z "$wlsdoc_now" ]; then
        echo "Required parameter not known: wlsdoc_now."
        return 1
    fi
    if [ -z "$wls_name" ]; then
        echo "Provide wls server name."
        return 1
    fi

    oldDst=$dst

    echo "*** Middleware discovery started"
    mw_home=$(getWLSjvmAttr $wls_name mw_home)
    domain_name=$(getWLSjvmAttr $wls_name domain_name)

    if [ -d $wlsdoc_now/$domain_name/middleware ]; then
        echo " >> middleware already discovered."
        echo "*** Middleware discovery done."
        return 1
    fi

    dst=$wlsdoc_now/$domain_name/middleware; mkdir -p $dst

    # opatch
    if [ -f $mw_home/OPatch/opatch ]; then
        echo -n ">> opatch inventory in progress..."
        dst=$wlsdoc_now/$domain_name/middleware/opatch; mkdir -p $dst
        $mw_home/OPatch/opatch lsinventory >$dst/inventory
        if [ $? -eq 0 ]; then
            echo "Completed"
        else
            touch $dst/error_opatch_inventory
            echo "Error: opatch not found."
        fi
    else
        touch $dst/opatch_not_found
    fi

    echo "*** Middleware discovery done."
    dst=$oldDst
}

function documentDomain() {

    if [ -z "$wlsdoc_now" ]; then
        echo "Required parameter not known: wlsdoc_now."
        return 1
    fi
    if [ -z "$(getDomainGroups)" ]; then
        echo "Domain information not found. Did you run discoverDomain?"
        return 1
    fi

    oldDst=$dst

    echo "*** Domain snapshot started."

    echo ">> writing domain info..."
    domain_name=$(getDomainAttr info name)
    dst=$wlsdoc_now/$domain_name
    mkdir -p $dst
    getDomainGroupAttrs info >$dst/info
    echo "OK"

    echo -n ">> domain bin scripts..."
    dst=$wlsdoc_now/$domain_name/bin
    mkdir -p $dst
    domain_home=$(getDomainAttr info home)
    cp -f $domain_home/bin/*.sh $dst
    echo "OK"

    echo -n ">> domain nodemanager bin scripts..."
    dst=$wlsdoc_now/$domain_name/nodemanager/bin
    mkdir -p $dst
    domain_home=$(getDomainAttr info home)

    if [ -d $domain_home/bin/nodemanager ]; then
        cp -f $domain_home/bin/nodemanager/*.sh $dst
        echo "OK"
    else
        echo "Skipped"
    fi

    echo ">> writing deployments with plan..."
    types=$(getDomainGroupAttrs | grep "^deployment$delim\type" | cut -f3 -d$delim | sort -u)
    for type in $types; do
        dst=$wlsdoc_now/$domain_name/deployments/$type
        mkdir -p $dst
        apps=$(getDomainGroupAttrs | grep "^deployment$delim\type$delim$type" | cut -f4 -d$delim)
        for app in $apps; do
            dst=$wlsdoc_now/$domain_name/deployments/$type/$app
            mkdir -p $dst
            plan_file=${domain_attr_groups[deployment$delim\type$delim$type$delim$app$delim\plan]}

            case $type in
            rar)
                echo -n ">> decoding rar $plan_file..."
                getWLS_ra_properties $plan_file >$dst/properties
                if [ $? -eq 0 ]; then
                    echo OK
                else
                    echo Error
                fi
                ;;
            esac
            echo -n ">> decoding generic $plan_file..."
            decode_deployment_plan $plan_file >$dst/config
            if [ $? -eq 0 ]; then
                echo OK
            else
                echo Error
            fi
        done
    done

    echo "*** Domain snapshot done."
    dst=$oldDst
}

##
## Process discovery
##

function document_host() {

    wlsdoc_bin="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    wlsdoc_root=~/oracle/weblogic
    mkdir -p $wlsdoc_root

    tmp=/tmp/$$
    mkdir -p $tmp

    unset IFS

    cat >$wlsdoc_root/README <<EOF
Weblogic resources are stored here in a form making it possible to track changes and compare between dates and hosts. 

ryszard.styczynsi@oracle.com, version 0.1 dev
EOF

    # document root
    wlsdoc_now=$wlsdoc_root/history/$(utc::now)
    mkdir -p $wlsdoc_now

    # wls discovery
    echo -n "*** WebLogic server discovery in progress..."
    source $wlsdoc_bin/wls_process_discovery.sh INIT
    discoverWLS
    echo "OK"

    # domain discovery
    echo -n "*** WebLogic domain discovery in progress..."
    source $wlsdoc_bin/resource_adapter_cfg_dump.sh
    source $wlsdoc_bin/domain_discovery.sh INIT
    
    domain_home=$(getWLSjvmAttr $wls_name domain_home)
    discoverDomain $domain_home
    echo "OK"

    unset domain_name
    # check existence of admin server
    if [ -z "${wls_admin[0]}" ]; then
        touch $wlsdoc_now/admin_not_found
    else
        wls_name=${wls_admin[0]}
        documentMW $wls_name
        domain_name=$(getWLSjvmAttr $wls_name domain_name)
    fi
    # check existence of managed servers
    if [ -z "${wls_managed[0]}" ]; then
        touch $wlsdoc_now/managed_not_found
    else
        wls_name=${wls_managed[0]}
        documentMW $wls_name
        domain_name=$(getWLSjvmAttr $wls_name domain_name)
    fi

    if [ ! -z "$domain_name" ]; then

        echo "************************************************************"
        echo "*** WebLogic domain snapshot started for: $domain_name"

        documentDomain $domain_name

        echo "*** WebLogic domain snapshot completed for: $domain_name"
        echo "************************************************************"

        # document servers
        for wls_name in ${wls_managed[*]}; do
            echo "************************************************************"
            echo "*** WebLogic server snapshot started for: $wls_name"
            documentWLS $wls_name

            echo "*** WebLogic server snapshot completed for: $wls_name"
            echo "************************************************************"
            echo
        done
    fi

    # copying snapshot to current
    mv $wlsdoc_root/current $wlsdoc_root/current.prv
    cp -r $wlsdoc_now $wlsdoc_root/current
    rm -rf $wlsdoc_root/current.prv

    # delete old files
    if [ ! -z "$wlsdoc_root" ]; then
        find $wlsdoc_root -mtime +30 -exec rm -f {} \;
    fi

    # make archive
    cd $wlsdoc_root/history
    tar -zcvf $wlsdoc_root/$(hostname)-document_host-history.tar.gz .
    cd $wlsdoc_root/current
    tar -zcvf $wlsdoc_root/$(hostname)-document_host-current.tar.gz .

    # copy to dropbox
    touch /var/wls-index-dropbox/test
    if [ $? -eq 0 ]; then
        rm -rf /var/wls-index-dropbox/*
        #cp -R $wlsdoc_root /var/wls-index-dropbox
        cp $wlsdoc_root/$(hostname)-document_host-all.tar.gz /var/wls-index-dropbox
    else
        echo "Snapshot not available for central manager as /var/wls-index-dropbox does not exist."
    fi

    echo "Done. Snapshot written here: $wlsdoc_root/current"

}

document_host
