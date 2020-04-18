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
    echo ">> machines..."
}

function harvester::getDSV() {

    machines=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for machine in $machines; do
        echo -n "$machine$delim"
        cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name[text()='$machine']/../node-manager/listen-address" - | removeStr '<listen-address>' | replaceStr '</listen-address>' '\n'
    done
}

function harvester::attachToDAG() {
    action=$1

    machines=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for machine in $machines; do
        machine_address=$(cat $tmp/clean_config.xml | 
            xmllint --xpath "/domain/machine/name[text()='$machine']/../node-manager/listen-address" - | 
            removeStr '<listen-address>' | replaceStr '</listen-address>' ''
            )

        domain_attr_groups[machine$delim$machine]=$machine_address
        domain_attr_groups[machine$delim$machine_address]=$machine

        if [ "$action" == print ]; then
            echo machine$delim${domain_attr_groups[machine$delim$machine]}
            echo machine$delim${domain_attr_groups[machine$delim$machine_address]}
        fi 

    done
}

