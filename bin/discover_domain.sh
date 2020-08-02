#!/bin/bash

###
### shared constants
###

delim='|'


###
### shared functions
###

function removeStr() {
    replaceStr $1 ''
}

function replaceStr() {
    change_from=$1
    change_to=$2

    change_from=$(echo $change_from | sed 's=/=\\/=g' | sed 's=]=\\]=g' | sed 's=\[=\\[=g')
    sed "s|$change_from|$change_to|g"
}


###
### local constants
###

if [[ $0 != $BASH_SOURCE ]]; then
    wlsdoc_bin="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
else
    wlsdoc_bin="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
fi

unset domain_attr_groups
declare -A domain_attr_groups


###
### local functions
###


# dump context to files
function discover_domain::dump() {
    context_dir=$1

    [ -z $context_dir ] && echo "Context directory not specified." && return 1

    tmp=/tmp/$$

    echo "# =======================================" >$tmp/discover_domain.dump
    echo "# =========== discover_domain ============" >>$tmp/discover_domain.dump
    echo "# ==============  dump ==================" >>$tmp/discover_domain.dump
    echo "# =======================================" >>$tmp/discover_domain.dump
    echo "# == host: $(hostname)" >>$tmp/discover_domain.dump
    echo "# == user: $(whoami)" >>$tmp/discover_domain.dump
    echo "# == date: $(date)" >>$tmp/discover_domain.dump

    # copy domain config directory
    mkdir $context_dir/discover_domain
    cp -R $domain_home/config $context_dir/discover_domain/
    echo "# == config: $context_dir/discover_domain/config" >>$tmp/discover_domain.dump
    echo "# == nodemanager: $context_dir/discover_domain/bin/nodemanager" >>$tmp/discover_domain.dump

    tar -zcvf $context_dir/discover_domain.tar.gz $domain_home/config $domain_home/bin/nodemanager >/dev/null

    echo "# == domain tar: $context_dir/discover_domain.tar.gz" >>$tmp/discover_domain.dump
    echo "# ======================================="  >>$tmp/discover_domain.dump
    
    # compute md5
    md5sum $context_dir/discover_domain.tar.gz > $context_dir/discover_domain.md5
    echo "#md5sum: $(md5sum $context_dir/discover_domain.tar.gz)" >> $tmp/discover_domain.dump
    mv $tmp/discover_domain.dump $context_dir/discover_domain.dump
}

# read context from files
function discover_domain::load() {
    echo Not implemented by intension. Use config directly from context directory.
}

# 

function getDomainGroups() {

    echo ${!domain_attr_groups[@]} | tr ' ' '\n' | cut -f1 -d"$delim" | sort -u

}

function getDomainGroupAttrs() {
    local attrGroup=$1

    keys=$(echo ${!domain_attr_groups[@]} | tr ' ' '\n' | grep "^$attrGroup")

    for key in $keys; do
        echo "$key=${domain_attr_groups[$key]}"
    done
}

function getDomainAttr() {
    local attrGroup=$1
    local attrName=$2

    key=$attrGroup$delim$attrName
    echo ${domain_attr_groups[$key]}
}

function domain::getSubCategory() {
    local category=$1

    for key in "${!domain_attr_groups[@]}"; do 
        echo "$key"
    done | grep "^$category$delim" | cut -d'|' -f2 | sort -u
}


function discoverDomain() {
    domain_home=$1

    if [ -z "$domain_home" ]; then
        echo "Usage: discoverDomain domain_home"
        return 1
    fi


    xmllint_vrsion=$(xmllint --version 2>&1 | grep libxml | cut -d' ' -f5)
    if [ $xmllint_vrsion -lt 20901 ]; then
        echo "Error. xmllint version too low. Cannot proceed."
        return 2
    fi

    tmp=/tmp/$$
    mkdir -p $tmp

    unset IFS

    #prepare config.xml
    cat $domain_home/config/config.xml |
        xmllint --format - |
        sed -e 's/xmlns=".*"//g' | # remove namespace definitions
        sed -E 's/\w+://g' |       # remove namespace use TODO: must be fixed, as not removes all words suffixed by :
        sed -E 's/nil="\w+"//g' |  # remove nil="true"
        perl -pe 's/xsi:type="[\w:-]*"//g' |  # remove xsi:type="
        perl -pe 's/xsi:nil="[\w:-]*"//g' |  # remove nxsi:nil=
        perl -pe 's/<\w+://g' |  # remove nxsi:nil=
        perl -pe 's/<\/\w+://g' |  # remove nxsi:nil=
        cat | xmllint --exc-c14n - >$tmp/clean_config.xml


    # files with numbers first, then alphanum order
    harvesters="$(ls $wlsdoc_bin/../harvesters | sort -n | grep '^[0-9]') $(ls $wlsdoc_bin/../harvesters | sort | grep '^[^0-9]')"

    for harvester in $harvesters; do
        source $wlsdoc_bin/../harvesters/$harvester

        harvester::header
        harvester::attachToDAG print
    done

    echo Done.

    # rm -f $tmp/clean_config.xml
}
