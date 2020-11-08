#!/bin/bash

wls_user=$1
wls_pass=$2

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

umc/lib/soadms-service.sh soadms-probe.yaml restart
