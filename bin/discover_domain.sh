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
### local constants
###

if [[ $0 != $BASH_SOURCE ]]; then
    wlsdoc_bin="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
else
    wlsdoc_bin="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
fi

unset domain_attr_groups
declare -A domain_attr_groups


###
### local functions
###

function getDomainGroups() {

    echo ${!domain_attr_groups[@]} | tr ' ' '\n' | cut -f1 -d"$delim" | sort -u

}

function getDomainGroupAttrs() {
    local attrGroup=$1

    keys=$(echo ${!domain_attr_groups[@]} | tr ' ' '\n' | grep "^$attrGroup")

    for key in $keys; do
        echo -n $key
        echo -n -e '\t'
        echo ${domain_attr_groups[$key]}
    done
}

# function getDomainAttr() {
#     local attrGroup=$1
#     local attrName=$2

#     key=$attrGroup$delim$attrName
#     echo ${domain_attr_groups[$key]} | cut -f2 -d"$delim"
# }


function discoverDomain() {
    domain_home=$1

    if [ -z "$domain_home" ]; then
        echo "Usage: discoverDomain domain_home"
        return 1
    fi

    domain_attr_groups=()

    tmp=/tmp/$$
    mkdir -p $tmp

    unset IFS

    #prepare config.xml
    cat $domain_home/config/config.xml |
        sed -e 's/xmlns=".*"//g' | # remove namespace definitions
        sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
        sed -E 's/nil="\w+"//g' |       # remove nil="true"
        cat | xmllint --exc-c14n - | xmllint --format - >$tmp/clean_config.xml


    harvesters=$(ls $wlsdoc_bin/../harvesters | sort -n)

    for harvester in $harvesters; do

        # to reset functions to avoid reusing one from other adapter
        source $wlsdoc_bin/../harvesters/dummy.sh

        source $wlsdoc_bin/../harvesters/$harvester

        harvester::header
        harvester::attachToDAG print

    done

    echo Done.

    # rm -f $tmp/clean_config.xml
}




