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
    echo ">> Clusters ..."
}

function harvester::getDSV() {

    category=cluster

    source $wlsdoc_bin/../lib/xml_tools.sh

    nodes=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/$category/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for name in $nodes; do
        xml_anchor="/domain/$category/name[text()='$name']/.."
        complex_nodes="."
        # run in subshell
        (xml_tools::node2DSV $tmp/clean_config.xml "server$delim$name" $xml_anchor "$complex_nodes")
    done
}

function harvester::attachToDAG() {
    action=$1

    source $wlsdoc_bin/../lib/xml_tools.sh
    
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
