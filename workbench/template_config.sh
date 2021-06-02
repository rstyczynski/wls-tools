#!/bin/bash

alert_path_vars_given=%env_files/x-ray/%env/%component/diag/wls/alert/%domain_name/%wls_server/%todayiso8601

alert_path_vars=$(echo $alert_path_vars_given | tr % $)

function set_variables() {

  source ~/oci-tools/bin/config.sh

  # set variables
  export env_files=$(getcfg x-ray env_files)
  export env=$(getcfg x-ray env)
  export component=$(getcfg x-ray component)

  export hostname=$(hostname)
}

function check_variables() {

  # check variables
  unset var_not_set
  test -z $env_files && var_not_set="${var_not_set} env_files"
  test -z $env && var_not_set="${var_not_set} env"
  test -z $component && var_not_set="${var_not_set} component"
  test -z $hostname && var_not_set="${var_not_set} hostname"
  test -z $domain_name && var_not_set="${var_not_set} domain_name"
  test -z $wls_server && var_not_set="${var_not_set} wls_server"

  if [ ! -z "$var_not_set" ]; then
    echo "Error. Variables are not set. Cannot contiune. Missing vars: $var_not_set"
    if [ -f $(echo $0) ]; then
      exit 1
    else
      return 1
    fi
  fi
}

function test_cfg() {

  echo
  echo Specified parameter
  echo $alert_path_vars_given
  
  #
  echo
  echo To be used as cfg for diganostics descriptor
  #
  # $env_files/x-ray/$env/$component/diag/wls/alert/$domain_name/$wls_server/$todayiso8601

  echo $alert_path_vars

  #
  echo
  echo To be used as parameter in cron
  #
  # /mwlogs/x-ray/pmaker/pmaker/diag/wls/alert/aa/zz/$(date -I)

  export todayiso8601="\$(date -I)"
  echo $alert_path_vars >~/tmp/alert_path_vars.$$
  alert_path_vardate=$(
    ~/oci-tools/bin/tpl2data.sh ~/tmp/alert_path_vars.$$
    rm ~/tmp/alert_path_vars.$$
  )
  echo $alert_path_vardate

  #
  echo
  echo To be used in script
  #
  # /mwlogs/x-ray/pmaker/pmaker/diag/wls/alert/aa/zz/2021-05-06

  export todayiso8601=$(date -I)
  echo $alert_path_vars >~/tmp/alert_path_vars.$$
  alert_path=$(
    ~/oci-tools/bin/tpl2data.sh ~/tmp/alert_path_vars.$$
    rm ~/tmp/alert_path_vars.$$
  )
  echo $alert_path
}

export domain_name=DOMAIN
export wls_server=WLS_SERVER

set_variables
check_variables
test $? -eq 0 && test_cfg
