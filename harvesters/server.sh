#!/bin/bash

#
# interface required tools
#

# xmllint cat sort tr

#
# interface required variables
#

# cat $tmp/clean_config.xml
# $delim
# domain_attr_groups
# $domain_home
# $wlsdoc_bin

#
# interface required functions
#
function harvester::header() {
    echo ">> Servers ..."
}

function harvester::getDSV() {

    source $wlsdoc_bin/../lib/xml_tools.sh

    servers=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/server/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for wls_name in $servers; do
        xml_anchor="/domain/server/name[text()='$wls_name']/.."
        complex_nodes="."
        # run in subshell
        (xml_tools::node2DSV $tmp/clean_config.xml "server$delim$wls_name" $xml_anchor "$complex_nodes")
    done
}

function harvester::attachToDAG() {
    action=$1

    IFS=$'\n'
    for data in $(harvester::getDSV); do

        key=$(echo $data | cut -f1 -d=)
        value=$(echo $data | cut -f2-9999 -d=)

        domain_attr_groups[$key]=$value

        if [ "$action" == print ]; then
            echo "$key=${domain_attr_groups[$key]}"
        fi
    done
    unset IFS

}

unset domain_attr_groups
declare -A domain_attr_groups
harvester::attachToDAG print
echo ${!domain_attr_groups[@]} | tr ' ' '\n'
