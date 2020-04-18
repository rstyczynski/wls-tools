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

    data=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/jta" - | grep -v 'jta>$' | sed 's/^ *<//g' | cut -f1 -d'<' | tr '>' $delim)

    for row in $data; do
        key=$(echo $data | cut -f1 -d$delim)
        value=$(echo $data | cut -f1 -d$delim)
        echo jta$delim\key$delim${domain_attr_groups[jta$delim$key]}
    done

}

function harvester::attachToDAG() {
    action=$1

    data=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/jta" - | grep -v 'jta>$' | sed 's/^ *<//g' | cut -f1 -d'<' | tr '>' $delim)

    for row in $data; do
        key=$(echo $data | cut -f1 -d$delim)
        value=$(echo $data | cut -f1 -d$delim)
        domain_attr_groups[jta$delim$key]=value

        if [ "$action" == print ]; then
            echo jta$delim\key$delim${domain_attr_groups[jta$delim$key]}
        fi 
    done


}

    
