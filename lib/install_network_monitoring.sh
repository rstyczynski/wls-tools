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
export domain_home=$(getWLSjvmAttr ${wls_managed[$srvNo]} -Ddomain.home)
export domain_name=$(basename $domain_home)


jdbc_url=$(cat $domain_home/config/jdbc/SOADataSource-jdbc.xml | grep url | perl -ne 'while(/<url>(.+)<\/url>/gm){print "$1\n";}')

export soa_jdbc_address=$(echo $jdbc_url | perl -ne 'while(/(.+)@\/\/(.+):(\d+)\/(.+)/gm){print "$2";}')
export soa_jdbc_port=$(echo $jdbc_url | perl -ne 'while(/(.+)@\/\/(.+):(\d+)\/(.+)/gm){print "$3";}')
export soa_jdbc_service_name=soa_db

echo $soa_jdbc_address
echo $soa_jdbc_port
echo $soa_jdbc_service_name

umc pingSocket collect 1 1 --subsystem $soa_jdbc_address:$soa_jdbc_port

cat >net-probe_soa-db.yml <<EOF
---
network:
      log_dir: ~/x-ray/diagnose/res/umc
      runtime_dir: ~/x-ray/watch/res/obd
      services:
        - oci:
                icmp:
                    - vcn:
                        ip: "169.254.169.254"
                    - internet:
                        ip: "8.8.8.8"
                tcp:
                    - vcn:
                        ip: "169.254.169.254:53"
                    - internet:
                        ip: "8.8.8.8:53"
        - \$domain_name:
                icmp:
                    - \$soa_jdbc_service_name:
                        ip: "$soa_jdbc_address"
                tcp:
                    - \$soa_jdbc_service_name:
                        ip: "\$soa_jdbc_address:\$soa_jdbc_port"
EOF


oci-tools/bin/tpl2data.sh net-probe_soa-db.yml  > ~/.umc/net-probe_soa-db.yml

# start
~/umc/lib/net-service.sh net-probe_soa-db.yml restart

# init cron
cron_section_start="# START umc - $domain_name network"
cron_section_stop="# STOP umc - $domain_name network"

cat >umc_net.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/net-service.sh net-probe_soa-db.yml restart
$cron_section_stop
EOF

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d"
cat umc_net.cron) | crontab -
rm umc_net.cron

crontab -l
