#!/bin/bash

# cat $tmp/clean_config.xml
# $delim
# domain_attr_groups
# $domain_home

function dummy::header() {
    echo ">> dummy..."
}

function dummy::getDSV() {

    echo "dummy$delim\value"
}

function dummy::attachToDAG() {
    action=$1

    domain_attr_groups[dummy$delim\dummy]=value

    if [ "$action" == print ]; then
        echo ${domain_attr_groups[dummy$delim\dummy]}
    fi 
}

    
