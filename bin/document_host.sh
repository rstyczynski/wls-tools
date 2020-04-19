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

function documentWLSruntime() {
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

    dst=$wlsdoc_now/$domain_name/runtime/servers/$wls_name
    mkdir -p $dst

    echo -n ">> top level information..."
    printAttrGroup $wls_name info >$dst/info
    substituteStringsGlobal $dst/info

    echo "Completed."

    echo -n ">> jvm details..."
    dst=$wlsdoc_now/$domain_name/servers/$wls_name/jvm
    mkdir -p $dst

    # jvm version
    $(getWLSjvmAttr $wls_name java_bin) -version >$dst/version 2>&1
    substituteStringsGlobal $dst/version

    # jvm arguments
    rm -f $dst/args
    for group in $(getWLSjvmGroups $wls_name); do
        printAttrGroup $wls_name $group >>$dst/args
        substituteStringsGlobal $dst/args

    done
    echo "Completed."

    echo "*** WebLogic server discovery done."
    dst=$oldDst
}

function documentMW() {
    local domain_name=$1
    local mw_home=$2
    
    [ -z "$wlsdoc_now" ] && echo "Error. wlsdoc_now must be set in env. Exiting..." && exit 1
    [ -z "$domain_name" ] && echo "Error. Wrong params. Usage: documentMW domain_name mw_home Exiting..." && exit 1 
    [ -z "$mw_home" ] && echo "Error. Wrong params. Usage: documentMW domain_name mw_home Exiting..." && exit 1 

    oldDst=$dst
    echo "*** Middleware discovery started"

    if [ -d $wlsdoc_now/$domain_name/middleware ]; then
        echo " >> middleware already discovered."
        echo "*** Middleware discovery done."
        return 1
    fi

    dst=$wlsdoc_now/$domain_name/middleware
    mkdir -p $dst

    # opatch
    if [ -f $mw_home/OPatch/opatch ]; then
        echo -n ">> opatch inventory in progress..."
        dst=$wlsdoc_now/$domain_name/middleware/opatch
        mkdir -p $dst
        $mw_home/OPatch/opatch lsinventory >$dst/inventory
        if [ $? -eq 0 ]; then
            substituteStringsGlobal $dst/inventory

            # format only to list ot patches
            cat $dst/inventory | tr -s ' ' | grep -e "^Patch [0-9]" | cut -d' ' -f1,2 | sort -t' ' -k2 -n > $dst/patches
            echo "Completed."
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

    # substitute
    #substituteStrings $dst/info $wlsdoc_now/$domain_name/variables
    substituteStringsGlobal $dst/info

    echo "OK"

    echo -n ">> domain bin scripts..."
    dst=$wlsdoc_now/$domain_name/bin
    mkdir -p $dst
    domain_home=$(getDomainAttr info home)
    cp -f $domain_home/bin/*.sh $dst

    # substitute
    cd $dst
    for script in $(ls *.sh); do
        #substituteStrings $script  $wlsdoc_now/$domain_name/variables
        substituteStringsGlobal $script
    done
    cd -
    echo "OK"

    echo -n ">> domain nodemanager bin scripts..."
    dst=$wlsdoc_now/$domain_name/nodemanager/bin
    mkdir -p $dst
    domain_home=$(getDomainAttr info home)

    if [ -d $domain_home/bin/nodemanager ]; then
        cp -f $domain_home/bin/nodemanager/*.sh $dst

        # substitute
        cd $dst
        for script in $(ls *.sh); do
            #substituteStrings $script $wlsdoc_now/$domain_name/variables
            substituteStringsGlobal $script
        done
        cd -

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
            plan_file=${domain_attr_groups[deployment$delim\type$delim$type$delim$app$delim\plan]}

            dst=$wlsdoc_now/$domain_name/deployments/$type
            mkdir -p $dst
            echo "$app $delim $plan_file" >>$dst/plan_files
            substituteStringsGlobal $dst/plan_files

            dst=$wlsdoc_now/$domain_name/deployments/$type/$app
            mkdir -p $dst

            case $type in
            rar)
                echo -n ">> decoding rar $plan_file..."
                getWLS_ra_properties $plan_file >$dst/properties
                if [ $? -eq 0 ]; then
                    substituteStringsGlobal $dst/properties
                    echo OK
                else
                    echo Error
                fi
                ;;
            esac

            echo -n ">> decoding generic $plan_file..."
            decode_deployment_plan $plan_file >$dst/config
            if [ $? -eq 0 ]; then
                substituteStringsGlobal $dst/config
                echo OK
            else
                echo Error
            fi
        done
    done

    echo -n ">> getting server details..."
    for wls_name in $(getWLSnames); do

        prepareServerSubstitutions $wls_name

        echo -n "$wls_name "
        dst=$wlsdoc_now/$domain_name/servers/$wls_name
        mkdir -p $dst
        getDomainGroupAttrs "server$delim$wls_name" | sort | cut -d$delim -f3-999 | grep -v "$delim" >$dst/config
        substituteStringsGlobal $dst/config

        cfg_groups=$(getDomainGroupAttrs "server$delim$wls_name" | sort | cut -d$delim -f3-999 | grep "$delim" | cut -d$delim -f1 | sort -u)
        for cfg_group in $cfg_groups; do
            dst=$wlsdoc_now/$domain_name/servers/$wls_name/$cfg_group
            mkdir -p $dst
            getDomainGroupAttrs "server$delim$wls_name$delim$cfg_group" | cut -d$delim -f4-999 >$dst/config
            substituteStringsGlobal $dst/config
        done
    done
    echo OK

    echo "*** Domain snapshot done."
    dst=$oldDst
}

function substituteStringsGlobal() {
    target_file=$1

    substituteStrings $target_file $wlsdoc_now/variables
    substituteStrings $target_file $wlsdoc_now/$domain_name/variables

    if [ -f $wlsdoc_now/$domain_name/servers/$wls_name/variables ]; then
        substituteStrings $target_file $wlsdoc_now/$domain_name/servers/$wls_name/variables
    fi
}

function substituteStrings() {
    src_file=$1
    variables=$2

    tmp=/tmp/$$
    mkdir -p $tmp

    cat $src_file >$tmp/substituteStrings_src_file
    for var in $(cat $variables); do
        key=$(cat $variables | grep -F "$var" | cut -f1 -d=)
        value=$(cat $variables | grep -F "$var" | cut -f2 -d=)
        #echo "$key, $value"
        cat $tmp/substituteStrings_src_file | replaceStr $value "\$[$key]" >$tmp/substituteStrings_src_file.new
        mv $tmp/substituteStrings_src_file.new $tmp/substituteStrings_src_file
    done
    cat $tmp/substituteStrings_src_file >$src_file
}

function prepareSystemSubstitutions() {
    dst=$wlsdoc_now
    mkdir -p $dst

    cat >$dst/variables <<EOF
Password, *********=assword",.*
[name="Password"]/value, *********=[name="Password"]/value,.*
{AES}********={AES}.*
EOF
}

function prepareDomainSubstitutions() {
    local domain_name=$1
    local wls_name=$2

    [ -z "$domain_name" ] && echo "Usage: prepareDomainSubstitutions wls_name" && exit 1
    [ -z "$wls_name" ] && echo "Usage: prepareDomainSubstitutions wls_name" && exit 1

    dst=$wlsdoc_now/$domain_name
    mkdir -p $dst

    cat >$dst/variables <<EOF
domain_home=$(getDomainHome)
domain_name=$(getDomainAttr info name)
admin_host=${wls_attributes[$wls_name$delim\admin_host_name]}
admin_port=${wls_attributes[$wls_name$delim\admin_host_port]}
mw_home=${wls_attributes[$wls_name$delim\mw_home]}
EOF
}

function prepareServerSubstitutions() {
    local wls_name=$1

    dst=$wlsdoc_now/$domain_name/servers/$wls_name
    mkdir -p $dst

    cat >$dst/variables <<EOF
server_host=$(getDomainGroupAttrs "server|$wls_name|listen-address$" | cut -f2)
server_port=$(getDomainGroupAttrs "server|$wls_name|listen-port$" | cut -f2)
os_pid=${wls_attributes[$wls_name$delim\os_pid]}
EOF
}

##
## Process discovery
##

function document_host() {

    echo "========================================================================================="
    echo "============================= Document host started ====================================="
    echo "========================================================================================="
    echo

    wlsdoc_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

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
    source $wlsdoc_bin/discover_processes.sh
    discoverWLS
    echo "OK"

    # domain discovery
    echo -n "*** WebLogic domain discovery in progress..."
    source $wlsdoc_bin/discover_domain.sh
    domain_home=$(getDomainHome)
    discoverDomain $domain_home
    echo "OK"

    #
    # prepare domain substitutes
    #
    prepareSystemSubstitutions
    unset domain_name
    # get domain name | thre may be no admin or no managed server on thi s host...
    [ ! -z "${wls_admin[0]}" ] && domain_name=$(getWLSjvmAttr ${wls_admin[0]} domain_name) && prepareDomainSubstitutions $domain_name ${wls_admin[0]}
    [ ! -z "${wls_managed[0]}" ] && domain_name=$(getWLSjvmAttr ${wls_managed[0]} domain_name) && prepareDomainSubstitutions $domain_name ${wls_managed[0]}

    #
    # document Middleware home
    #

    if [ ! -z "$domain_name" ]; then

        echo "************************************************************"
        echo "*** WebLogic middleware snapshot started for: $domain_name"

        unset mw_home
        [ ! -z "${wls_admin[0]}" ] && mw_home=$(getWLSjvmAttr ${wls_admin[0]} mw_home)
        [ ! -z "${wls_managed[0]}" ] && mw_home=$(getWLSjvmAttr ${wls_managed[0]} mw_home)
        
        if [ ! -z "$mw_home" ]; then
            documentMW $domain_name $mw_home
            echo "*** WebLogic middleware snapshot completed for: $domain_name"
            echo "************************************************************"
            echo 
        else
            echo "Error: Not able to detect MW_HOME."
            echo "*** WebLogic middleware snapshot ERRORED for: $domain_name"
            echo "************************************************************"
            echo 
        fi

        echo "************************************************************"
        echo "*** WebLogic domain snapshot started for: $domain_name"
        documentDomain $domain_name
        echo "*** WebLogic domain snapshot completed for: $domain_name"
        echo "************************************************************"
        echo 

        # document servers
        for wls_name in $(getWLSnames); do
            echo "************************************************************"
            echo "*** WebLogic server snapshot started for: $wls_name"
            documentWLSruntime $wls_name
            echo "*** WebLogic server snapshot completed for: $wls_name"
            echo "************************************************************"
            echo
        done

    fi

    # copying snapshot to current
    mv $wlsdoc_root/current $wlsdoc_root/current.prv
    cp -r $wlsdoc_now $wlsdoc_root/current
    rm -rf $wlsdoc_root/current.prv

    # delete old files; checking few dirs to protects against error leading to removel of wrong files
    if [ ! -z "$wlsdoc_root" ]; then
        if [ -d $wlsdoc_root/current ]; then
            if [ -f $wlsdoc_root/README ]; then
                if [ -d $wlsdoc_root/history ]; then
                    echo -n "Removing snapshots older than 30 days..."
                    find $wlsdoc_root/history -mtime +30 -exec rm -f {} \;
                    echo "Done"
                fi
            fi
        fi
    fi

    # make archive
    echo ">> preparing tar files..."
    cd $wlsdoc_root/history
    tar -zcvf $wlsdoc_root/$(hostname)-document_host-history.tar.gz . >/dev/null
    cd $wlsdoc_root/current
    tar -zcvf $wlsdoc_root/$(hostname)-document_host-current.tar.gz . >/dev/null

    # copy to dropbox
    echo ">> copying to outbox..."
    dropbox=NO
    touch /var/wls-index-dropbox/test
    if [ $? -eq 0 ]; then
        rm -rf /var/wls-index-dropbox/*
        #cp -R $wlsdoc_root /var/wls-index-dropbox
        cp $wlsdoc_root/$(hostname)-document_host-history.tar.gz /var/wls-index-dropbox
        cp $wlsdoc_root/$(hostname)-document_host-current.tar.gz /var/wls-index-dropbox
        dropbox=YES
    else
        echo "Snapshot not available for central manager as /var/wls-index-dropbox does not exist."
    fi

    echo
    echo "========================================================================================="
    echo "============================ Document host completed ===================================="
    echo "========================================================================================="
    echo "Snapshot is available here: $wlsdoc_root/current."
    echo

    if [ $dropbox == NO ]; then
        echo "As /var/wls-index-dropbox is not available, transfter below files manually to host doing compare operation."
        echo "- current archive:    $wlsdoc_root/$(hostname)-document_host-current.tar.gz "
        echo "- historical archive: $wlsdoc_root/$(hostname)-document_host-history.tar.gz"
    else
        echo "Snapshots for remote access via /var/wls-index-dropbox are ready."
        echo "- current archive:    /var/wls-index-dropbox/$(hostname)-document_host-current.tar.gz"
        echo "- historical archive: /var/wls-index-dropbox/$(hostname)-document_host-history.tar.gz"
    fi
    echo "========================================================================================="
    echo "========================================================================================="
}

document_host
