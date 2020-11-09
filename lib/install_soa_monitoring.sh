#!/bin/bash

wls_user=$1; shift
wls_pass=$1; shift

if [ -z "$wls_user" ] || [ -z "$wls_pass" ]; then
    echo "Usage: install_soa_monitoring.sh user pass [tools dir]"
    exit 1
fi

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
    cp -rf $tools_src/umc ~/
    cp -rf $tools_src/wls-tools ~/
    cp -rf $tools_src/oci-tools ~/
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
