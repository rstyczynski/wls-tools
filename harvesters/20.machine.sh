#!/bin/bash

# cat $tmp/clean_config.xml
# $delim
# domain_attr_groups


function machine::header() {
    echo ">> machines..."
}

function machine::getDSV() {

    machines=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for machine in $machines; do
        echo -n "$machine$delim"
        cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name[text()='$machine']/../node-manager/listen-address" - | removeStr '<listen-address>' | replaceStr '</listen-address>' '\n'
    done
}

function machine::attachToDAG() {

    machines=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/machine/name" - | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for machine in $machines; do
        machine_address=$(cat $tmp/clean_config.xml | 
            xmllint --xpath "/domain/machine/name[text()='$machine']/../node-manager/listen-address" - | 
            removeStr '<listen-address>' | replaceStr '</listen-address>' ''
            )

        domain_attr_groups[machine$delim$machine]=$machine_address
        domain_attr_groups[machine$delim$machine_address]=$machine
    done
}

