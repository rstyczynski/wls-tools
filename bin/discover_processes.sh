#!/bin/bash

###
### shared constants
###

delim='|'

unset wls_attributes
declare -A wls_attributes
unset wls_attributes_groups
declare -A wls_attributes_groups

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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

# dump context to files
function discover_processes::dump() {
    context_dir=$1

    [ -z $context_dir ] && echo "Context directory not specified." && return 1

    tmp=/tmp/$$

    echo "# =======================================" >$tmp/discover_processes.dump
    echo "# ========= discover_processes ==========" >>$tmp/discover_processes.dump
    echo "# ==============  dump ==================" >>$tmp/discover_processes.dump
    echo "# =======================================" >>$tmp/discover_processes.dump
    echo "# == host: $(hostname)" >>$tmp/discover_processes.dump
    echo "# == user: $(whoami)" >>$tmp/discover_processes.dump
    echo "# == date: $(date)" >>$tmp/discover_processes.dump
    echo "# =======================================" >>$tmp/discover_processes.dump
    declare -p wls_names >>$tmp/discover_processes.dump
    declare -p wls_managed >>$tmp/discover_processes.dump
    declare -p wls_admin >>$tmp/discover_processes.dump
    declare -p wls_attributes >>$tmp/discover_processes.dump
    declare -p wls_attributes_groups >>$tmp/discover_processes.dump

    # add signature or cipher dump
    md5sum $tmp/discover_processes.dump >$context_dir/discover_processes.md5
    echo "#md5sum: $(md5sum $tmp/discover_processes.dump)" >>$tmp/discover_processes.dump
    mv $tmp/discover_processes.dump $context_dir/discover_processes.dump
}

# read context from files
function discover_processes::load() {
    dump_file=$1

    test ! -f $dump_file && echo Dump file not specified. && return 1

    source $dump_file
}

#
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

        \rm $tmp/skiplines.$$
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
    domain_config=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=([\w\/]+)} && print "$1"')
    #echo $domain_path

    wls_attributes[$wls_server$delim\domain_config]=$domain_config
    wls_attributes_groups[$wls_server$delim\main$delim\domain_config]=$domain_config

    export wls_server
    #regexp="(\w+)\s+\d+.+java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=$domain_config"
    os_user=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{(\w+)\s+\d+.+java -server.+-Dweblogic.Name=$wls_server} && print "$1"')
    wls_attributes[$wls_server$delim\os_user]=$os_user
    wls_attributes_groups[$wls_server$delim\info$delim\os_user]=$os_user

    export wls_server
    #regexp="\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server.+-Doracle.domain.config.dir=$domain_config"
    os_pid=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server} && print "$1"')

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

    #echo 'Java binary version:'
#     java_version="$(sudo su - $os_user <<EOF
# $java_bin -version 2>&1 | tr '\n' ' ' 
# EOF
# )"
    java_version="$($java_bin -version 2>&1 | tr '\n' ' ')"
    echo $java_version >$tmp/skiplines.$$
    wls_attributes[$wls_server$delim\java_version]="$java_version"
    wls_attributes_groups[$wls_server$delim\info$delim\java_version]="$java_version"

    #echo
    #echo 'Java boot jar:'
    boot_jar=$(echo $proc_cmd | tr ' ' '\n' | tail -1)
    echo $boot_jar >>$tmp/skiplines.$$
    wls_attributes[$wls_server$delim\boot_jar]=$boot_jar
    wls_attributes_groups[$wls_server$delim\main$delim\boot_jar]=$boot_jar

    proc_cmd=$(echo $proc_cmd | tr ' ' '\n' | grep -v -f $tmp/skiplines.$$ | sort -u)

    unset IFS
    for attrGroup in $attr_groups; do
        # echo $attrGroup
        collectAttrGroup $attrGroup
    done

    collectAttrGroup OTHER
}

function discoverWLSjvmCfg() {

    echo ">> discovering server configuration..."

    for wls_server in $(getWLSnames); do
        echo "================================"
        echo "================================"
        echo "====== $wls_server"
        echo "================================"
        analyzeWLSjava $wls_server 'Xm server cp Dlaunch da java Xloggc verbose Djava XX:+ XX:- XX Doracle DHTTPClient Dorg.apache.commons.logging DJAAS DUSE_JAAS Djps Dweblogic Ddomain.home Dwls Dtangosol Dmft Dums Dem Dcommon Djrf Dopss Dadf'
        echo "================================"
    done
}

function discoverWLSroles() {

    echo ">> discovering server roles..."

    for wls_server in $(getWLSnames); do

        echo "================================"
        echo "================================"
        echo "====== $wls_server"
        echo "================================"
        wls_mgmt_svr=${wls_attributes_groups[$wls_server$delim\Dweblogic$delim\-Dweblogic.management.server]}

        if [ ! -z "$wls_mgmt_svr" ]; then

            wls_managed+=($wls_server)

            protocol=$(echo $wls_mgmt_svr | cut -d'/' -f1 | cut -f1 -d:)
            host=$(echo $wls_mgmt_svr | cut -d'/' -f3 | cut -f1 -d:)
            port=$(echo $wls_mgmt_svr | cut -d'/' -f3 | cut -f2 -d:)

            echo "Server role:  Managed server."
            echo "Admin server: $protocol://$host:$port"

            attrGroup=info
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_protocol]=$protocol
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_name]=$host
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\admin_host_port]=$port

            wls_attributes[$wls_server$delim\admin_host_protocol]=$protocol
            wls_attributes[$wls_server$delim\admin_host_name]=$host
            wls_attributes[$wls_server$delim\admin_host_port]=$port
        else
            echo "Server role: Admin server."
            wls_admin+=($wls_server)
        fi

        domain_home=$(getWLSjvmAttr $wls_server -Ddomain.home)
        if [ -z "$domain_home" ]; then
            echo -n "Notice. Domain home not found in expected location. Trying to discover from process environment..."
            os_pid=$(getWLSjvmAttr $wls_server os_pid)
            domain_home=$(xargs -0 -L1 -a /proc/$os_pid/environ | grep "^DOMAIN_HOME" | head -1 | cut -d= -f2)
        fi
        if [ -f "$domain_home" ]; then
            echo "Found."
            echo "Domain home: $domain_home"
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_name]=$(basename $domain_home)
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_home]=$(basename $domain_home)
            wls_attributes[$wls_server$delim\domain_home]=$(basename $domain_home)
            wls_attributes[$wls_server$delim\domain_name]=$(basename $domain_home)
        else
            echo "Error. Not found."
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_name]=undefined
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\domain_home]=undefined
            wls_attributes[$wls_server$delim\domain_home]=undefined
            wls_attributes[$wls_server$delim\domain_name]=undefined
        fi
        wls_home=$(getWLSjvmAttr $wls_server -Dweblogic.home)
        if [ -z "$wls_home" ]; then
            echo -n "Notice. WebLogic home not found in expected location. Trying to discover from process environment..."
            os_pid=$(getWLSjvmAttr $wls_server os_pid)
            wls_home=$(xargs -0 -L1 -a /proc/$os_pid/environ | grep "^WLS_HOME" | head -1 | cut -d= -f2)
        fi
        if [ -f "$wls_home" ]; then
            echo "Found."
            echo "WebLogic home: $wls_home"
            echo "Middleware home: $(echo $wls_home | sed 's|/wlserver/server$||')"
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\mw_home]=$(echo $wls_home | sed 's|/wlserver/server$||')
            wls_attributes[$wls_server$delim\mw_home]=$(echo $wls_home | sed 's|/wlserver/server$||')
        else
            echo "Error. Not found."
            wls_attributes_groups[$wls_server$delim$attrGroup$delim\mw_home]=undefined
            wls_attributes[$wls_server$delim\mw_home]=undefined
        fi
        echo "================================"
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

    # NOADMIN-OK
    local domain_home=$(getWLSjvmAttr ${wls_admin[0]} domain_home)
    if [ -z "$domain_home" ]; then
        domain_home=$(getWLSjvmAttr ${wls_managed[0]} domain_home)
    fi
    echo $domain_home
}

function getDomainName() {

    # NOADMIN-OK
    local domain_name=$(getWLSjvmAttr ${wls_admin[0]} domain_name)
    if [ -z "$domain_name" ]; then
        domain_name=$(getWLSjvmAttr ${wls_managed[0]} domain_name)
    fi
    echo $domain_name
}

function showSample() {

    getWLSjvmAttrs ${wls_names[0]}
    echo
    echo "================================"
    echo "====== ${wls_names[0]}  attributes get groups"
    echo "================================"
    getWLSjvmGroups ${wls_names[0]}
    echo
    echo "================================"
    echo "====== ${wls_names[0]}  group attributes"
    echo "================================"
    getWLSjvmGroupAttr ${wls_names[0]}

    echo "================================"
    echo "====== ${wls_names[0]} attributes from XX group"
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
    echo "====== Admin attributes ========"
    echo "===== from given group ========="
    echo "================================"
    if [ -z "${wls_admin[0]}" ]; then
        echo "Info: No admin server found on this host."
    else
        printAttrGroup ${wls_admin[0]} info
        printAttrGroup ${wls_admin[0]} main
    fi
    echo
    echo "================================"
    echo "==== First managed server ======"
    echo "==attributes from given group ="
    echo "================================"
    if [ -z "${wls_managed[0]}" ]; then
        echo "Info: No managed server found on this host."
    else
        printAttrGroup ${wls_managed[0]} info
        printAttrGroup ${wls_managed[0]} main
    fi
}

function discoverWLS() {

    unset wls_names
    wls_names=()

    wls_attributes=()

    wls_attributes_groups=()

    unset wls_managed
    wls_managed=()

    unset wls_admin
    wls_admin=()

    tmp=/tmp/$$
    mkdir -p $tmp

    discoverWLSnames

    if [ -z ${wls_names[0]} ]; then
        echo "Weblogic not detected on this host."
        return 1
    fi

    discoverWLSjvmCfg
    discoverWLSroles
}

function wls() {
    server_name=$1
    action=$2

    # wls get soa_server1 jvm args
}
