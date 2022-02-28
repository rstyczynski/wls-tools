#!/bin/bash

tools_src=$1; shift

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

os_user=$(getWLSjvmAttr ${wls_managed[0]} os_user)

admin_host_protocol=$(getWLSjvmAttr ${wls_managed[0]} admin_host_protocol)
admin_host_name=$(getWLSjvmAttr ${wls_managed[0]} admin_host_name)
admin_host_port=$(getWLSjvmAttr ${wls_managed[0]} admin_host_port)

adminURL_suffix=$admin_host_name:$admin_host_port
admin_server=${wls_admin[0]}
domain_name=$(getWLSjvmAttr ${wls_managed[0]} domain_name) 

if [ ! -z "$admin_server" ]; then
    cat ~/umc/lib/wls-probe.yaml | 
    sed "s/soa_domain/$domain_name/" |
    sed "s/admin: oracle/admin: $os_user/" | 
    sed "s/url: t3:\/\/localhost:7001/url: t3:\/\/$adminURL_suffix/" |
    sed "s/admin_server: AdminServer/admin_server: $admin_server/" > ~/.umc/wls-probe.yaml
else
  rm -rf ~/.umc/wls-probe.yaml
fi

# Configure middleware homes

mw_home=$(getWLSjvmAttr ${wls_managed[0]} mw_home)
wls_home=$(getWLSjvmAttr ${wls_managed[0]} wls_home)
domain_home=$(getWLSjvmAttr ${wls_managed[0]} domain_home)
soa_home=$(getWLSjvmAttr ${wls_managed[0]} -Dsoa.oracle.home)
osb_home=$(getWLSjvmAttr ${wls_managed[0]} -Doracle.osb.home)

cat > ~/.umc/umc.conf <<EOF
export FMW_HOME=$mw_home
export SOA_HOME=$soa_home
export OSB_HOME=$osb_home
export WLS_HOME=$wls_home
export DOMAIN_HOME=$domain_home
EOF

# Test WLS connectivity
if [ -z "$admin_server" ] || [ -z $mw_home ] || [ -z $wls_home ] || [ -z $domain_home ]; then
    echo "Admin server not found. Test skipped."
    echo "admin_server: $admin_server"
    echo "mw_home: $mw_home"
    echo "wls_home: $wls_home"
    echo "domain_home: $domain_home"
else
    url="t3://$adminURL_suffix" 
    source ~/umc/bin/umc.h
    umc wls collect 1 2 --subsystem=datasource --url=$url --server=$admin_server
fi


# start OS collector

if [ -z "$admin_server" ] || [ -z $mw_home ] || [ -z $wls_home ] || [ -z $domain_home ]; then
        echo "Admin server not found. Service start skipped. Stoping service as sanity step."
    $HOME/umc/lib/wls-service.sh wls-probe.yaml stop
else
    $HOME/umc/lib/wls-service.sh wls-probe.yaml restart
fi

# init cron
cron_section_start="# START umc - $domain_name DMS"
cron_section_stop="# STOP umc - $domain_name DMS"

if [ -z "$admin_server" ] || [ -z $mw_home ] || [ -z $wls_home ] || [ -z $domain_home ]; then
    echo "Admin server, MW home, WLS home, or Domain home not found - delete DMS section from cron"
    (crontab -l 2>/dev/null | 
    sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
else
    cat >umc_dms.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/wls-service.sh wls-probe.yaml restart
$cron_section_stop
EOF
    (crontab -l 2>/dev/null | 
    sed "/$cron_section_start/,/$cron_section_stop/d"
    cat umc_dms.cron) | crontab -
    rm umc_dms.cron

    crontab -l
fi

