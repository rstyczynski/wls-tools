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
### local functions
###

function decode_deployment_plan() {
    plan_file=$1

    tmp=/tmp/$$/decode_deployment_plan
    mkdir -p $tmp

    # Remove name space information as it makes xmllint confused with not well defined xpaths
    cat $plan_file | sed -e 's/xmlns=".*"//g' >$tmp/clean_plan.xml

    # 1. take all variable names from module

    modules=$(cat $tmp/clean_plan.xml |
        xmllint --xpath "/deployment-plan/module-override/module-name" - |
        sed 's|</module-name>|\n|g; s|<module-name>||g' |
        sort)

    for module_name in $modules; do

        echo "--------------------------------"
        echo "--- Module $module_name"
        echo "--------------------------------"
        cat $tmp/clean_plan.xml | xmllint --xpath "/deployment-plan/module-override/module-name[text()='$module_name']/../module-descriptor/variable-assignment/name" - 2>/dev/null |
            sed 's|</name>|\n|g; s|<name>||g' >$tmp/var_names 

        if [ ! -s $tmp/var_names ]; then
            echo "(none)"
        else
            # 2. for each variable take xpath and value

            IFS=$'\n' # there are names with space...
            for var_name in $(cat $tmp/var_names); do
                #echo $var_name

                #module_name=fabric-wls.war
                #var_name=ServletDescriptor_Oracle Restful WebService_ServletName_154721284270330
                # 2.1 get destination xpath
                xmllint --xpath "/deployment-plan/module-override/module-name[text()='$module_name']/../module-descriptor/variable-assignment/name[text()='$var_name']/../xpath/text()" $tmp/clean_plan.xml >$tmp/var_xpath 2>/dev/null
                if [ $? -eq 10 ]; then #XPath set is empty is returned when response is null
                    echo -n "(none)" >$tmp/var_xpath
                fi

                # 2.2 get assigned value
                xmllint --xpath "/deployment-plan/variable-definition/variable/name[starts-with(.,'$var_name')]/../value/text()" $tmp/clean_plan.xml >$tmp/var_value 2>/dev/null
                if [ $? -eq 10 ]; then #XPath set is empty is returned when response is null
                    echo -n "(none)" >$tmp/var_value
                fi

                echo "$(cat $tmp/var_xpath), $(cat $tmp/var_value)" >>$tmp/modul_cfg
            done

            unset IFS
            cat $tmp/modul_cfg
            rm $tmp/modul_cfg
        fi

    done

    rm -rf $tmp
    unset tmp
}

function getWLS_ra_properties() {
    plan_file=$1

    tmp=/tmp/$$
    mkdir -p $tmp

    # Remove name space information as it makes xmllint confused with not well defined xpaths
    cat $plan_file | sed -e 's/xmlns=".*"//g' >$tmp/clean_plan.xml

    # 1. take all variable names from module

    module_name=weblogic-connector
    xmllint --xpath "/deployment-plan/module-override/module-descriptor/root-element[starts-with(.,'$module_name')]/../variable-assignment/name" $tmp/clean_plan.xml |
        sed 's|</name>|\n|g; s|<name>||g' >$tmp/var_names

    # 2. for each variable take xpath and value

    for var_name in $(cat $tmp/var_names); do
        #echo $var_name

        # 2.1 get destination xpath
        xmllint --xpath "/deployment-plan/module-override/module-descriptor/root-element[starts-with(.,'weblogic-connector')]/../variable-assignment/name[starts-with(.,'$var_name')]/../xpath/text()" $tmp/clean_plan.xml >$tmp/var_xpath 2>/dev/null
        if [ $? -eq 10 ]; then #XPath set is empty is returned when response is null
            echo -n "(none)" >$tmp/var_xpath
        fi

        # 2.2 get assigned value
        xmllint --xpath "/deployment-plan/variable-definition/variable/name[starts-with(.,'$var_name')]/../value/text()" $tmp/clean_plan.xml >$tmp/var_value 2>/dev/null
        if [ $? -eq 10 ]; then #XPath set is empty is returned when response is null
            echo -n "(none)" >$tmp/var_value
        fi

        echo "$(cat $tmp/var_xpath), $(cat $tmp/var_value)" >>$tmp/modul_cfg
    done

    cat $tmp/modul_cfg |
        removeStr '/weblogic-connector/outbound-resource-adapter/connection-definition-group/[connection-factory-interface="javax.resource.cci.ConnectionFactory"]/connection-instance/[jndi-name=' |
        cat |                                                                  # remove ra cfg prefix
        replaceStr ']/connection-properties/properties/property/[name=' ', ' | # remove ra cfg decorations
        removeStr ']/value' |                                                  # remove ra cfg decorations
        grep -v '/name, ' |                                                    # remove ra cfg name variable as not necessary here
        cat                                                                    # Done.

}
