#!/bin/bash

###
### shared constants
###

delim='|'

###
### shared functions
###
function removeStr() {
    replaceStr $1 ''
}

function replaceStr() {
    change_from=$1
    change_to=$2

    change_from=$(echo $change_from | sed 's=/=\\/=g' | sed 's=]=\\]=g' | sed 's=\[=\\[=g')
    sed "s|$change_from|$change_to|g"
}

###
### local functions
###

function discoverWLSnames() {
    discoverWLSroles
    wls_names=()

    for wls_name in $(ps aux | grep java | perl -ne 'm{java -server.+-Dweblogic.Name=(\w+)} && print "$1\n"'); do
        wls_names+=($wls_name)
    done

    echo ${wls_names[@]}
}

function collectAttrGroup() {
    attrGroup=$1

    if [ ! -f $tmp/skiplines.$$ ]; then
        touch $tmp/skiplines.$$
    fi

    if [ "$attrGroup" != OTHER ]; then
        attrs=$(echo $proc_cmd | tr ' ' '\n' | grep -v -f $tmp/skiplines.$$ | grep "\-$attrGroup")
        if [ ! -z "$attrs" ]; then
            for attr in $attrs; do
                attr_name=$(echo $attr | cut -f1 -d'=')
                attr_value=$(echo $attr | cut -f2 -d'=')
                wls_attributes[$wls_server$delim$attr_name]=$attr_value
                wls_attributes_groups[$wls_server$delim$attrGroup$delim$attr_name]=$attr_value

                echo $attr >>$tmp/skiplines.$$
            done
        else
            attr_name='(none)'
            attr_value='(none)'
            wls_attributes_groups[$wls_server$delim$attrGroup$delim$attr_name]=$attr_value
        fi

    else

        attrs=$(echo $proc_cmd | tr ' ' '\n' | grep -v -f $tmp/skiplines.$$)
        if [ ! -z "$attrs" ]; then
            for attr in $attrs; do
                attr_name=$(echo $attr | cut -f1 -d'=')
                attr_value=$(echo $attr | cut -f2 -d'=')
                wls_attributes[$wls_server$delim$attr_name]=$attr_value
                wls_attributes_groups[$wls_server$delim\OTHER$delim$attr_name]=$attr_value
            done
        fi

        rm $tmp/skiplines.$$
    fi
}

function analyzeWLSjava() {
    wls_server=$1
    attr_groups=$2

    if [ -z "$attr_groups" ]; then
        attr_groups='Xm server cp Dlaunch da java Xloggc verbose Djava XX:+ XX:- XX Doracle DHTTPClient Dorg.apache.commons.logging DJAAS DUSE_JAAS Djps Dweblogic Ddomain.home Dwls Dtangosol Dmft Dums Dem Dcommon Djrf Dopss Dadf'
    fi

    #echo "=== $wls_server"
    export wls_server
    domain_config=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=([\w\/]+)} && print "$1 "')
    #echo $domain_path

    wls_attributes[$wls_server$delim\domain_config]=$domain_config
    wls_attributes_groups[$wls_server$delim\main$delim\domain_config]=$domain_config

    export wls_server
    #regexp="(\w+)\s+\d+.+java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=$domain_config"
    os_user=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{(\w+)\s+\d+.+java -server.+-Dweblogic.Name=$wls_server} && print "$1 "')
    wls_attributes[$wls_server$delim\os_user]=$os_user
    wls_attributes_groups[$wls_server$delim\info$delim\os_user]=$os_user

    export wls_server
    #regexp="\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=$domain_config"
    os_pid=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server} && print "$1 "')

    #echo $os_pid
    wls_attributes[$wls_server$delim\os_pid]=$os_pid
    wls_attributes_groups[$wls_server$delim\info$delim\os_pid]=$os_pid

    proc_cmd=$(ps -o command ax -q $os_pid | tail -1 | sed 's/-cp /-cp=/g')

    echo
    #echo 'Java binary:'
    java_bin=$(echo $proc_cmd | tr ' ' '\n' | head -1)
    echo $java_bin >$tmp/skiplines.$$
    wls_attributes[$wls_server$delim\java_bin]=$java_bin
    wls_attributes_groups[$wls_server$delim\info$delim\java_bin]=$java_bin

    #echo
    #echo 'Java boot jar:'
    boot_jar=$(echo $proc_cmd | tr ' ' '\n' | tail -1)
    echo $boot_jar >>$tmp/skiplines.$$
    wls_attributes[$wls_server$delim\boot_jar]=$boot_jar
    wls_attributes_groups[$wls_server$delim\main$delim\boot_jar]=$boot_jar

    proc_cmd=$(echo $proc_cmd | tr ' ' '\n' | grep -v -f $tmp/skiplines.$$ | sort -u)

    for attrGroup in $attr_groups; do
        collectAttrGroup $attrGroup
    done

    collectAttrGroup OTHER
}

function discoverWLSjvmCfg() {
    for wls_server in $(getWLSnames); do

        echo "================================"
        echo "================================"
        echo "====== $wls_server"
        echo "================================"
        echo "================================"
        analyzeWLSjava $wls_server 'Xm server cp Dlaunch da java Xloggc verbose Djava XX:+ XX:- XX Doracle DHTTPClient Dorg.apache.commons.logging DJAAS DUSE_JAAS Djps Dweblogic Ddomain.home Dwls Dtangosol Dmft Dums Dem Dcommon Djrf Dopss Dadf'
    done
}

function discoverWLSroles() {

    for wls_server in $(getWLSnames); do

        echo "================================"
        echo "================================"
        echo "====== $wls_server"
        echo "================================"
        echo "================================"
        wls_mgmt_svr=${wls_attributes_groups[$wls_server$delim\Dweblogic$delim\-Dweblogic.management.server]}

        if [ ! -z "$wls_mgmt_svr" ]; then

            wls_managed+=($wls_server)

            protocol=$(echo $wls_mgmt_svr | cut -d'/' -f1 | cut -f1 -d:)
            host=$(echo $wls_mgmt_svr | cut -d'/' -f3 | cut -f1 -d:)
            port=$(echo $wls_mgmt_svr | cut -d'/' -f3 | cut -f2 -d:)

            echo Server role: Managed server.
            echo Admin server:
            echo - protocol: $protocol
            echo - host: $host
            echo - port: $port

            attrGroup=info
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_protocol]=$protocol
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_name]=$host
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_port]=$port

            wls_attributes[$wls_server$delim\admin_host_protocol]=$protocol
            wls_attributes[$wls_server$delim\admin_host_name]=$host
            wls_attributes[$wls_server$delim\admin_host_port]=$port
        else
            echo Server role: Admin server.
            wls_admin+=($wls_server)
        fi

        wls_attributes_groups[$wls_server$delim$attrGroup$delim\mw_home]=$(getWLSjvmAttr $wls_server -Dweblogic.home | sed 's|/wlserver/server$||')
        wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_home]=$(getWLSjvmAttr $wls_server -Ddomain.home)
        wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_name]=$(basename $(getWLSjvmAttr $wls_server -Ddomain.home))

        wls_attributes[$wls_server$delim\mw_home]=$(getWLSjvmAttr $wls_server -Dweblogic.home | sed 's|/wlserver/server$||')
        wls_attributes[$wls_server$delim\domain_home]=$(getWLSjvmAttr $wls_server -Ddomain.home)
        wls_attributes[$wls_server$delim\domain_name]=$(basename $(getWLSjvmAttr $wls_server -Ddomain.home))

    done
}

function getWLSnames() {

    echo ${wls_names[@]}
}

function getWLSjvmAttrs() {
    wls_server=$1

    echo ${!wls_attributes[@]} | tr ' ' '\n' | grep "^$wls_server" | sed "s/^$wls_server$delim//g" | sort
}

function getWLSjvmGroupAttr() {
    wls_server=$1
    group=$2

    if [ ! -z "$group" ]; then
        attrs=$(echo ${!wls_attributes_groups[@]} | tr ' ' '\n' | grep "^$wls_server" | sed "s/^$wls_server_//g" | sort | grep "$delim$group$delim")
        for key in $attrs; do
            attr=$(echo $key | cut -d$delim -f3)
            echo $attr ${wls_attributes_groups[$key]}
        done

    else
        echo ${!wls_attributes_groups[@]} | tr ' ' '\n' | grep "^$wls_server" | sed "s/^$wls_server_//g" | sort | cut -d$delim -f2,3
    fi

}

function getWLSjvmGroups() {
    wls_server=$1

    echo ${!wls_attributes_groups[@]} | tr ' ' '\n' | grep "^$wls_server" | sed "s/^$wls_server_//g" | cut -d$delim -f2 | sort -u

}

function getWLSjvmAttr() {
    wls_server=$1
    attr_name=$2

    echo ${wls_attributes[$wls_server$delim$attr_name]}

}

function printAttrGroup() {
    wls_name=$1
    group=$2

    echo
    echo "$group attributes:"
    echo "================"
    if [ "$group" != info ]; then
        getWLSjvmGroupAttr $wls_name $group | sed "s/$delim/\t/g" |
            replaceStr ${wls_attributes[$wls_name$delim\java_bin]} '$JAVA_BIN' |
            replaceStr ${wls_attributes[$wls_name$delim\domain_home]} '$domain_home' |
            replaceStr ${wls_attributes[$wls_name$delim\mw_home]} '$mw_home'
    else
        getWLSjvmGroupAttr $wls_name $group | sed "s/$delim/\t/g"
    fi

}

function getDomainHome() {
    local domain_home=$(getWLSjvmAttr ${wls_admin[0]} domain_home)
    if [ -z "domain_home" ]; then
        domain_home=$(getWLSjvmAttr ${wls_managed[0]} domain_home)
    fi
    echo $domain_home
}

function discoverWLS() {
    discoverWLSnames
    discoverWLSjvmCfg
    discoverWLSroles
}

unset wls_names
wls_names=()

unset wls_attributes
declare -A wls_attributes

unset wls_attributes_groups
declare -A wls_attributes_groups

unset wls_managed
wls_managed=()

unset wls_admin
wls_admin=()

tmp=/tmp/$$
mkdir -p $tmp

case $1 in

INIT)
    discoverWLS
    echo "Discovered servers: $(getWLSnames)."
    ;;

*)
    discoverWLS

    getWLSnames

    echo
    echo "================================"
    echo "====== $wls_server attributes"
    echo "================================"
    getWLSjvmAttrs ${wls_names[0]}
    echo
    echo "================================"
    echo "====== $wls_server attributes get groups"
    echo "================================"
    getWLSjvmGroups ${wls_names[0]}
    echo
    echo "================================"
    echo "====== $wls_server group attributes"
    echo "================================"
    getWLSjvmGroupAttr ${wls_names[0]}

    echo "================================"
    echo "====== $wls_server attributes from XX group"
    echo "================================"
    getWLSjvmGroupAttr ${wls_names[0]} XX
    echo
    echo "================================"
    echo "====== ${wls_names[0]} get all attribute groups"
    echo "================================"
    for group in $(getWLSjvmGroups ${wls_names[0]}); do
        printAttrGroup ${wls_names[0]} $group
    done
    echo
    echo "================================"
    echo "====== ${wls_admin[0]} attributes from given group"
    echo "================================"
    printAttrGroup ${wls_admin[0]} info
    printAttrGroup ${wls_admin[0]} main
    echo
    echo "================================"
    echo "====== ${wls_managed[0]} attributes from given group"
    echo "================================"
    printAttrGroup ${wls_managed[0]} info
    printAttrGroup ${wls_managed[0]} main
    ;;

esac
