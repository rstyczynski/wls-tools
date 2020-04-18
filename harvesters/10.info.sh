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
    echo ">> general info..."
}

function harvester::getDSV() {

    echo "info$delim\name$delim$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/name/text()" -)"
    echo "info$delim\version$delim$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/domain-version/text()" -)"
    echo "info$delim\home$delim$domain_home"
}

function harvester::attachToDAG() {
    action=$1

    domain_attr_groups[info$delim\name]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/name/text()" -)
    domain_attr_groups[info$delim\version]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/domain-version/text()" -)
    domain_attr_groups[info$delim\home]=$domain_home

    if [ "$action" == print ]; then
        echo info$delim\name$delim${domain_attr_groups[info$delim\name]}
        echo info$delim\version$delim${domain_attr_groups[info$delim\version]}
        echo info$delim\home$delim${domain_attr_groups[info$delim\home]}
    fi 
}

    
