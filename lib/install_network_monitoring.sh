#!/bin/bash

tools_src=$1; shift
extra_services=$1; shift

: ${tools_src:=git}

# get libraries
case $tools_src in
git)
    cd ~
    test -d umc && (cd umc; git pull)
    test -d umc || git clone https://github.com/rstyczynski/umc.git

    test -d wls-tools && (cd wls-tools; git pull)
    test -d wls-tools || git clone https://github.com/rstyczynski/wls-tools.git

    test -d oci-tools && (cd oci-tools; git pull)
    test -d oci-tools || git clone https://github.com/rstyczynski/oci-tools.git
    ;;
*)
    if [ ! -d $tools_src/umc ]; then
        echo "Error. umc not available at shared location. Put it there before proceeding"
        exit 1
    fi
    cp -rf --preserve=mode,timestamps  $tools_src/umc ~/

    if [ ! -d $tools_src/wls-tools ]; then
        echo "Error. wls-tools not available at shared location. Put it there before proceeding"
        exit 1
    fi
    cp -rf --preserve=mode,timestamps  $tools_src/wls-tools ~/
    
    if [ ! -d $tools_src/oci-tools ]; then
        echo "Error. oci-tools not available at shared location. Put it there before proceeding"
        exit 1
    fi
    cp -rf --preserve=mode,timestamps  $tools_src/oci-tools ~/
    ;;
esac


# prepare cfg directory
umc_cfg=~/.umc
mkdir -p $umc_cfg

source wls-tools/bin/discover_processes.sh 

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

discoverWLS
export domain_home=$(getWLSjvmAttr ${wls_managed[$srvNo]} -Ddomain.home)

if [ ! -z $domain_home ]; then
export domain_name=$(basename $domain_home)

test -f $domain_home/config/jdbc/WLSSchemaDataSource-jdbc.xml && jdbc_src=$domain_home/config/jdbc/WLSSchemaDataSource-jdbc.xml 
test -f $domain_home/config/jdbc/SOADataSource-jdbc.xml && jdbc_src=$domain_home/config/jdbc/SOADataSource-jdbc.xml 
test -f $domain_home/config/jdbc/MFTDataSource-jdbc.xml && jdbc_src=$domain_home/config/jdbc/MFTDataSource-jdbc.xml 


jdbc_url=$(cat $jdbc_src | grep url | perl -ne 'while(/<url>(.+)<\/url>/gm){print "$1\n";}')

export wls_jdbc_service_name=wls_db

# simple URL
export wls_jdbc_address=$(echo $jdbc_url | perl -ne 'while(/(.+)@\/\/(.+):(\d+)\/(.+)/gm){print "$2";}')
export wls_jdbc_port=$(echo $jdbc_url | perl -ne 'while(/(.+)@\/\/(.+):(\d+)\/(.+)/gm){print "$3";}')

# url w/o //
: ${wls_jdbc_address:=$(echo $jdbc_url | perl -ne 'while(/(.+)@(.+):(\d+)\/(.+)/gm){print "$2";}')}
: ${wls_jdbc_port:=$(echo $jdbc_url | perl -ne 'while(/(.+)@(.+):(\d+)\/(.+)/gm){print "$3";}')}

# orcle style connectino string
: ${wls_jdbc_address:=$(echo $jdbc_url | tr '(' '\n' | tr -d ')' | grep HOST | cut -f2 -d=)}
: ${wls_jdbc_port:=$(echo $jdbc_url | tr '(' '\n' | tr -d ')' | grep PORT | cut -f2 -d=)}



echo $wls_jdbc_address
echo $wls_jdbc_port
echo $wls_jdbc_service_name

# init and test umc
source ~/umc/bin/umc.h
umc pingSocket collect 1 1 --subsystem $wls_jdbc_address:$wls_jdbc_port

# build data collection descriptor
cat >net-probe.yaml <<EOF
---
network:
      log_dir: ~/x-ray/diag/net/log
      runtime_dir: ~/x-ray/watch/net/obd
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
                    - \$wls_jdbc_service_name:
                        ip: "$wls_jdbc_address"
                tcp:
                    - \$wls_jdbc_service_name:
                        ip: "\$wls_jdbc_address:\$wls_jdbc_port"
EOF

else
    echo Weblogic not detected.

cat >net-probe.yaml <<EOF
---
network:
      log_dir: ~/x-ray/diag/net/log
      runtime_dir: ~/x-ray/watch/net/obd
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
EOF
fi

if [ ! -z "$extra_services" ]; then
    echo "$extra_services" | sed 's/>/    /g' >> net-probe.yml
fi

oci-tools/bin/tpl2data.sh net-probe.yaml  > ~/.umc/net-probe.yml

# start
~/umc/lib/net-service.sh net-probe.yaml restart

# init cron
cron_section_start="# START umc - $domain_name network"
cron_section_stop="# STOP umc - $domain_name network"

cat >umc_net.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/net-service.sh net-probe.yml restart
$cron_section_stop
EOF

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d"
cat umc_net.cron) | crontab -
rm umc_net.cron

crontab -l
