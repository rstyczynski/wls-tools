#!/bin/bash

~/umc/lib/net-service.sh net-probe_soa-db.yml stop

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
