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
    echo ">> dummy..."
}

function harvester::getDSV() {

    echo "dummy$delim\value"
}

function harvester::attachToDAG() {
    action=$1

    domain_attr_groups[dummy$delim\dummy]=$value

    if [ "$action" == print ]; then
        echo dummy$delim${domain_attr_groups[dummy$delim\dummy]}
    fi 
}

    
