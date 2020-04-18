#!/bin/bash

###
### shared constants
###

delim='|'

unset domain_attr_groups
declare -A domain_attr_groups

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

function getDomainGroups() {

    echo ${!domain_attr_groups[@]} | tr ' ' '\n' | cut -f1 -d"$delim" | sort -u

}

function getDomainGroupAttrs() {
    local attrGroup=$1

    keys=$(echo ${!domain_attr_groups[@]} | tr ' ' '\n' | grep "^$attrGroup")

    # for key in $keys; do
    #     echo -n "$(echo $key | cut -f2 -d"$delim")"
    #     echo -n -e '\t'
    #     echo ${domain_attr_groups[$key]} | cut -f2 -d"$delim"
    # done

    for key in $keys; do
        echo -n $key
        echo -n -e '\t'
        echo ${domain_attr_groups[$key]}
    done
}

function getDomainAttr() {
    local attrGroup=$1
    local attrName=$2

    key=$attrGroup$delim$attrName
    echo ${domain_attr_groups[$key]} | cut -f2 -d"$delim"
}

function discoverServer() {
    domain_home=$1
    wls_name=$2

    if [ ! -f $tmp/clean_config.xml ]; then
        # prepare config.xml
        cat $domain_home/config/config.xml |
            sed -e 's/xmlns=".*"//g' | # remove namespace definitions
            sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
            sed -E 's/nil="\w+"//g' |       # remove nil="true"
            cat >$tmp/clean_config.xml
    fi

    # get list of basic nodes for server
    basic_nodes=$(cat $tmp/clean_config.xml | xmllint xmllint --format - | xmllint --xpath "/domain/server/name[text()='$wls_name']/../*[not(*)]" - | sed 's/></>\n</g' | tr '>' '<' | cut -d'<' -f2)

    # print values
    for node in $basic_nodes; do
        echo $node | grep "/$" >/dev/null
        if [ $? -eq 0 ]; then
            # tag w/o value
            value="(exist)"
        else
            value=$(cat $tmp/clean_config.xml  | xmllint --xpath "/domain/server/name[text()='$wls_name']/../$node/text()" -)
        fi
        #echo "$node$delim$value"
        domain_attr_groups[server$delim$wls_name$delim$node]=$value
    done

    # get complex types
    complex_nodes=$(cat $tmp/clean_config.xml  | xmllint xmllint --format - | xmllint --xpath "/domain/server/name[text()='$wls_name']/../*[(*)]" - | sed 's/></>\n</g' | grep -v '^ ' | tr -d '<' | tr -d '>')

    for node in $complex_nodes; do
        node_details=$(cat $tmp/clean_config.xml  | xmllint --xpath "/domain/server/name[text()='$wls_name']/../$node" - | 
        grep -v "<$section>"  | grep -v "</$section>" | 
        tr '>' '<' | 
        cut -d'<' -f2,3 | 
        sed "s/</$delim/g" | 
        grep -v "$delim$" | 
        sort -u | 
        sed "s/^/$node$delim/g")

        IFS=$'\n'
        for node in $node_details; do
            key=$(echo $node | cut -d$delim -f1,2)
            value=$(echo $node | cut -d$delim -f3)
            domain_attr_groups[server$delim$wls_name$delim$key]=$value
        done
        unset IFS
    done
}

function discoverDomainXX() {
    local domain_home=$1

    domain_attr_groups=()

    tmp=/tmp/$$
    mkdir -p $tmp

    unset IFS

    # prepare config.xml
    cat $domain_home/config/config.xml |
        sed -e 's/xmlns=".*"//g' | # remove namespace definitions
        sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
        sed -E 's/nil="\w+"//g' |       # remove nil="true"
        cat >$tmp/clean_config.xml

    # info
    echo ">> general info..."
    domain_attr_groups[info$delim\name]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/name/text()" -)
    domain_attr_groups[info$delim\version]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/domain-version/text()" -)
    domain_attr_groups[info$delim\home]=$domain_home

    # deployments
    echo ">> deployments..."
    deployment_types=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type" - |
        removeStr '<module-type>' | replaceStr '</module-type>' '\n' | sort -u | tr '\n' ' ')

    # deployments with configuratino plan
    echo ">> deployments with plan..."
    for type in $deployment_types; do
        cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type[text()='$type']/../plan-path[text()]/../name" - >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Deployments $type with plan:"
            apps=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type[text()='$type']/../plan-path[text()]/../name" - |
                removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

            for app in $apps; do
                plan_file=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/name[text()='$app']/../plan-path/text()" -)
                domain_attr_groups[deployment$delim\type$delim$type$delim$app$delim\plan]=$plan_file

                echo -n $app
                echo -en '\t'
                echo $plan_file

            done

        else
            echo "No deployments $type with plan found."
        fi
    done

    # echo -n ">> server details..."
    # for wls_name in $(getWLSnames); do
    #     echo -n "$wls_name "
    #     discoverServer $domain_home $wls_name
    # done

    echo Done.

    # rm -f $tmp/clean_config.xml
}


function discoverDomain() {
    local domain_home=$1

    domain_attr_groups=()

    tmp=/tmp/$$
    mkdir -p $tmp

    unset IFS

    # prepare config.xml
    cat $domain_home/config/config.xml |
        sed -e 's/xmlns=".*"//g' | # remove namespace definitions
        sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
        sed -E 's/nil="\w+"//g' |       # remove nil="true"
        cat >$tmp/clean_config.xml

    harvesters=$(ls $wlsdoc_bin/../harvesters | sort -n)

    for harvester in $harvesters; do

        source $wlsdoc_bin/../harvesters/$harvester

        harvester::header
        harvester::attachToDAG print

    done


    echo Done.

    # rm -f $tmp/clean_config.xml
}


if [[ $0 != $BASH_SOURCE ]]; then
    wlsdoc_bin="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
else
    wlsdoc_bin="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
fi


