#!/bin/bash

# get umc
cd 
if [ -d umc ]; then
    cd ~/umc; git pull; cd -
else
    git clone https://github.com/rstyczynski/umc.git
fi

# prepare cfg directory
umc_cfg=~/.umc
mkdir -p $umc_cfg

if [ -d wls-tools ]; then
    cd wls-tools; git pull; cd -
else
    git clone https://github.com/rstyczynski/wls-tools.git
fi

source wls-tools/bin/discover_processes.sh 

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

discoverWLS

os_user=$(getWLSjvmAttr ${wls_managed[0]} os_user)

admin_host_protocol=$(getWLSjvmAttr ${wls_managed[0]} admin_host_protocol)
admin_host_name=$(getWLSjvmAttr ${wls_managed[0]} admin_host_name)
admin_host_port=$(getWLSjvmAttr ${wls_managed[0]} admin_host_port)

adminURL_suffix=$admin_host_name:$admin_host_port
admin_Server=${wls_admin[0]}

if [ ! -z "$admin_Server" ]; then
cat ~/umc/lib/wls-probe.yaml | 
sed "s/admin: oracle/admin: $os_user/" | 
sed "s/url: t3:\/\/localhost:7001/url: t3:\/\/$adminURL_suffix/" |
sed "s/admin_server: AdminServer/admin_server: $admin_Server/" > ~/.umc/wls-probe.yaml
else
  rm -rf ~/.umc/wls-probe.yaml
fi

# Configure middleware homes

mw_home=$(getWLSjvmAttr ${wls_managed[0]} mw_home)
soa_home=$(getWLSjvmAttr ${wls_managed[0]} -Dsoa.oracle.home)
osb_home=$(getWLSjvmAttr ${wls_managed[0]} -Doracle.osb.home)
wls_home=$(getWLSjvmAttr ${wls_managed[0]} -Dweblogic.home)
domain_home=$(getWLSjvmAttr ${wls_managed[0]} -Ddomain.home)

cat > ~/.umc/umc.conf <<EOF
export FMW_HOME=$mw_home
export SOA_HOME=$soa_home
export OSB_HOME=$osb_home
export WLS_HOME=$wls_home
export DOMAIN_HOME=$domain_home
EOF

# Test WLS connectivity

url="t3://$adminURL_suffix" 

source ~/umc/bin/umc.h

umc wls collect 1 2 --subsystem=datasource --url=$url

# start OS collector

if [ ! -z "$admin_Server" ]; then
    $HOME/umc/lib/wls-service.sh wls-probe.yaml restart
else
    echo "Admin server not found."
fi

# init cron

cron_section_start="# START umc - $domain_name DMS"
cron_section_stop="# STOP umc - $domain_name DMS"

if [ ! -z "$admin_Server" ]; then
    cat >umc_dms.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/wls-service.sh wls-probe.yaml restart
$cron_section_stop
EOF
    (crontab -l 2>/dev/null | 
    sed "/$cron_section_start/,/$cron_section_stop/d"
    cat umc_dms.cron) | crontab -
    rm umc_dms.cron
else
    echo "Admin server not found - delete DMS section from cron"
    (crontab -l 2>/dev/null | 
    sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
fi

crontab -l
