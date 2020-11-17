#!/bin/bash

$HOME/umc/lib/soadms-service.sh soadms-probe.yaml stop

source wls-tools/bin/discover_processes.sh 

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

discoverWLS
domain_home=$(getWLSjvmAttr ${wls_managed[0]} -Ddomain.home)

cron_section_start="# START umc - $domain_name SOA DMS"
cron_section_stop="# STOP umc - $domain_name SOA DMS"
(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
