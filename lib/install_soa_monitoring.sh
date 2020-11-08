#!/bin/bash

wls_user=$1
wls_pass=$2

if [ -z "$wls_user" ] || [ -z "$wls_pass" ]; then
    echo "Usage: install_soa_monitoring.sh user pass"
    exit 1
fi

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

# Build SOA resource definition

admin_host_protocol=$(getWLSjvmAttr ${wls_managed[0]} admin_host_protocol)
admin_host_name=$(getWLSjvmAttr ${wls_managed[0]} admin_host_name)
admin_host_port=$(getWLSjvmAttr ${wls_managed[0]} admin_host_port)

adminURL_suffix=$admin_host_name:$admin_host_port
admin_Server=${wls_admin[0]}

if [ ! -z "$admin_Server" ]; then
cat ~/umc/lib/soadms-probe.yaml | 
sed "s/url: http:\/\/localhost:7001/url: $admin_host_protocol:\/\/$adminURL_suffix/" > ~/.umc/soadms-probe.yaml
else
  rm -rf ~/.umc/soadms-probe.yaml
fi

# Set WLS password

source ~/umc/bin/umc.h

url=$admin_host_protocol://$adminURL_suffix

pnp_vault save user$url $wls_user
pnp_vault save pass$url $wls_pass

# Test WLS dms/Spy connectivity

wls_user=$(pnp_vault read user$url)
wls_pass=$(pnp_vault read pass$url)

dms-collector --url $url --connect "$wls_user/$wls_pass" --count 1 --delay 1 --loginform --table soainfra_status

# Start SOA collector

if [ ! -z "$admin_Server" ]; then
    $HOME/umc/lib/soadms-service.sh soadms-probe.yaml restart
else
    echo "Admin server not found."
fi

# init cron

cron_section_start="# START umc - $domain_name SOA DMS"
cron_section_stop="# STOP umc - $domain_name SOA DMS"

if [ ! -z "$admin_Server" ]; then
cat >umc_dms.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/soadms-service.sh soadms-probe.yaml restart
$cron_section_stop
EOF

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d"
cat umc_dms.cron) | crontab -
rm umc_dms.cron
else
(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
fi

crontab -l
