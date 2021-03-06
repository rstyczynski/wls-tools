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
    harvester::xml_generic_with_name::header "JPA"
}

function harvester::getDSV() {
    harvester::xml_generic_with_name::getDSV jpa
}

function harvester::attachToDAG() {
     harvester::xml_generic_with_name::attachToDAG jpa $1
}
