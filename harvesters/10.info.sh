#!/bin/bash

# cat $tmp/clean_config.xml
# $delim
# domain_attr_groups
# $domain_home

function info::header() {
    echo ">> general info..."
}

function info::getDSV() {

    echo "name$delim$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/name/text()" -)"
    echo "version$delim$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/domain-version/text()" -)"
    echo "home$delim$domain_home"
}

function info::attachToDAG() {
    action=$1

    domain_attr_groups[info$delim\name]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/name/text()" -)
    domain_attr_groups[info$delim\version]=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/domain-version/text()" -)
    domain_attr_groups[info$delim\home]=$domain_home

    if [ "$action" == print ]; then
        echo ${domain_attr_groups[info$delim\name]}
        echo ${domain_attr_groups[info$delim\version]}
        echo ${domain_attr_groups[info$delim\home]}
    fi 
}

    
