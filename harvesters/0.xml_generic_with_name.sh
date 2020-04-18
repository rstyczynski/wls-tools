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
function harvester::xml_generic_with_name::header() {
    header=$1
    
    if [ ! -z "$header" ]; then
        echo ">> $header ..."
    else
        echo ">> Loaded xml_generic_with_name."
    fi
}

function harvester::xml_generic_with_name::getDSV() {
    category=$1

    [ -z "$category" ] && return 1

    source $wlsdoc_bin/../lib/xml_tools.sh

    nodes=$(xmllint --xpath "/domain/$category/name" $tmp/clean_config.xml  | removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

    for name in $nodes; do
        xml_anchor="/domain/$category/name[text()='$name']/.."
        complex_nodes="."
        # run in subshell
        (xml_tools::node2DSV $tmp/clean_config.xml "$category$delim$name" "$xml_anchor" "$complex_nodes")
    done
}

function harvester::xml_generic_with_name::attachToDAG() {
    category=$1
    action=$2

    [ -z "$category" ] && return 1
    [ "$category" == print ] && return 1

    source $wlsdoc_bin/../lib/xml_tools.sh
    
    IFS=$'\n'
    for data in $(harvester::getDSV $category); do

        key=$(echo $data | cut -f1 -d=)
        value=$(echo $data | cut -f2-9999 -d=)

        domain_attr_groups[$key]=$value

        if [ "$action" == print ]; then
            echo "$key=${domain_attr_groups[$key]}"
        fi

        if [ "$key" == 'descriptor-file-name' ]; then
            
            cat $domain_home/config/$value |
                sed -e 's/xmlns=".*"//g' | # remove namespace definitions
                sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
                sed -E 's/nil="\w+"//g' |       # remove nil="true"
                cat | xmllint --exc-c14n - | xmllint --format - >$tmp/clean_$category.xml

            xml_root_tag=$(cat $tmp/clean_$category.xml | xmllint --xpath "/" - | sed 's/></>\n</g' | grep -v '^ ' | tr -d '<' | tr -d '>' | grep -v '^/' | grep -v '^?xml')
            cfg_name=$(cat $tmp/clean_$category.xml | xmllint --xpath "/$xml_root/name/text()" -)
            xml_tools::node2DSV $tmp/clean_$category.xml "$xml_root$delim$cfg_name" "/$xml_root_tag" $xml_root_tag
        fi 

    done
    unset IFS

}
