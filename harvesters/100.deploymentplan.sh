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
    echo ">> deployments with plan..."
}

function harvester::getDSV() {
    getDeploymentPlans getDSV
}

function harvester::attachToDAG() {
    action=$1

    getDeploymentPlans attachToDAG $action
}

#
# custom functions
#

function getDeploymentPlans() {
    action=$1; shift
    subaction=$1; shift

    source $wlsdoc_bin/decode_resource_adapter_cfg.sh

    deployment_types=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type" - |
    removeStr '<module-type>' | replaceStr '</module-type>' '\n' | sort -u | tr '\n' ' ')

    for type in $deployment_types; do
        cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type[text()='$type']/../plan-path[text()]/../name" - >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Deployments $type with plan:"
            apps=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/module-type[text()='$type']/../plan-path[text()]/../name" - |
                removeStr '<name>' | replaceStr '</name>' '\n' | sort -u)

            for app in $apps; do
                plan_file=$(cat $tmp/clean_config.xml | xmllint --xpath "/domain/app-deployment/name[text()='$app']/../plan-path/text()" -)

                case $action in
                    attachToDAG)
                        domain_attr_groups[deployment$delim\type$delim$type$delim$app$delim\plan]=$plan_file
                        if [ "$subaction" == print ]; then
                            echo "$app$delim$plan_file"
                        fi
                        ;;

                    getDSV)
                        echo "$app$delim$plan_file"
                        ;;
                esac

            done

        else
            echo "Warning. No deployments $type with plan found."
        fi
    done
}

    
