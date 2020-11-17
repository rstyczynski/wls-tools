#!/bin/bash


service_files=$(ls ~/.umc/net-probe*.yml)

for service_file in $service_files; do
    service=$(basename $service_file)

    echo stopping $service...
    $HOME/umc/lib/net-service.sh $service stop 
    rm -rf $service_file
done


source wls-tools/bin/discover_processes.sh 

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

discoverWLS
domain_home=$(getWLSjvmAttr ${wls_managed[0]} -Ddomain.home)

# init cron
cron_section_start="# START umc - $domain_name network"
cron_section_stop="# STOP umc - $domain_name network"

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
